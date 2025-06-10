defmodule Thunderline.Tick.TickWorker do
  @moduledoc """
  Oban Worker for executing PAC tick cycles.

  This worker implements the core "heartbeat" of Thunderline - the periodic
  execution of PAC reasoning and evolution. Each tick represents a moment
  where a PAC:

  1. Evaluates its current state and environment
  2. Retrieves relevant memories and context
  3. Uses AI reasoning (via Jido agents) to make decisions
  4. Updates its state and performs actions
  5. Logs the tick for continuity and debugging
  6. Schedules the next tick cycle

  Ticks are fault-tolerant and resumable thanks to Oban's reliability.
  """

  use Oban.Worker,
    queue: :pacs,
    max_attempts: 3,
    unique: [period: 60, fields: [:worker, :args]]

  require Logger

  alias Thunderline.{PAC, Repo}
  alias Thunderline.Tick.{Pipeline, Log}
  alias Thunderline.Memory.Manager, as: MemoryManager

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"pac_id" => pac_id} = args}) do
    Logger.debug("Starting tick for PAC #{pac_id}")

    with {:ok, pac} <- load_pac(pac_id),
         {:ok, context} <- build_tick_context(pac, args),
         {:ok, result} <- Pipeline.execute_tick(pac, context),
         {:ok, _log} <- Log.create_tick_log(pac, result) do

      # Schedule next tick
      schedule_next_tick(pac, result)

      Logger.debug("Completed tick for PAC #{pac.name} (#{pac_id})")
      :ok
    else
      {:error, :pac_not_found} ->
        Logger.warn("PAC #{pac_id} not found, skipping tick")
        :ok

      {:error, :pac_inactive} ->
        Logger.info("PAC #{pac_id} is inactive, stopping ticks")
        :ok

      {:error, reason} ->
        Logger.error("Tick failed for PAC #{pac_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp load_pac(pac_id) do
    case Ash.get(PAC, pac_id, domain: Thunderline.Domain) do
      {:ok, pac} ->
        if pac.last_tick_at do
          {:ok, pac}
        else
          {:error, :pac_inactive}
        end

      {:error, _} ->
        {:error, :pac_not_found}
    end
  end

  defp build_tick_context(pac, args) do
    # Calculate time since last tick
    time_since_last_tick =
      if pac.last_tick_at do
        DateTime.diff(DateTime.utc_now(), pac.last_tick_at, :second)
      else
        0
      end

    # Get zone context if PAC is in a zone
    zone_context =
      if pac.zone_id do
        case Ash.get(Thunderline.PAC.Zone, pac.zone_id, domain: Thunderline.Domain) do
          {:ok, zone} ->
            %{
              zone: zone,
              zone_pacs: get_zone_pacs(zone.id),
              zone_rules: zone.rules,
              zone_modifiers: zone.modifiers
            }
          _ -> %{}
        end
      else
        %{}
      end

    # Retrieve relevant memories
    memories = MemoryManager.get_relevant_memories(pac.id, limit: 10)

    context = %{
      time_since_last_tick: time_since_last_tick,
      tick_count: pac.tick_count,
      zone_context: zone_context,
      memories: memories,
      job_args: args
    }

    {:ok, context}
  end

  defp get_zone_pacs(zone_id) do
    PAC
    |> Ash.Query.filter(zone_id == ^zone_id and not is_nil(last_tick_at))
    |> Ash.read!(domain: Thunderline.Domain)
    |> Enum.reject(&(&1.id == zone_id)) # Exclude self
  end

  defp schedule_next_tick(pac, result) do
    # Calculate next tick delay based on PAC state and energy
    base_interval = Application.get_env(:thunderline, :base_tick_interval, 300) # 5 minutes

    # Adjust interval based on energy and activity
    energy_ratio = get_in(pac.stats, ["energy"]) / 100.0
    interval_multiplier =
      case get_in(result, [:state_changes, "activity"]) do
        "active" -> 0.7    # More frequent ticks when active
        "resting" -> 1.5   # Less frequent when resting
        "sleeping" -> 3.0  # Much less frequent when sleeping
        _ -> 1.0           # Default interval
      end

    adjusted_interval =
      base_interval * interval_multiplier * (2.0 - energy_ratio)
      |> trunc()
      |> max(60)  # Minimum 1 minute between ticks
      |> min(3600) # Maximum 1 hour between ticks

    # Schedule the next tick
    %{pac_id: pac.id}
    |> __MODULE__.new(schedule_in: adjusted_interval)
    |> Oban.insert!()

    Logger.debug("Scheduled next tick for PAC #{pac.name} in #{adjusted_interval} seconds")
  end
end
