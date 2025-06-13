defmodule Thunderline.Tick.TickWorker do
  @moduledoc """
  Oban Worker for executing PAC Agent tick cycles.

  This worker implements the core "heartbeat" of Thunderline - the periodic
  execution of PAC Agent reasoning and evolution. Each tick represents a moment
  where a PAC Agent:

  1. Evaluates its current state and environment
  2. Retrieves relevant memories and context
  3. Uses AI reasoning (via Jido agents) to make decisions
  4. Updates its state and performs actions
  5. Logs the tick for continuity and debugging
  6. Schedules the next tick cycle

  Ticks are fault-tolerant and resumable thanks to Oban's reliability.
  """

  use Oban.Worker,
    queue: :tick,
    max_attempts: 3,
    unique: [period: 60, fields: [:worker, :args]]

  require Logger

  alias Thunderline.PAC.{Agent, Zone, Manager}
  alias Thunderline.Tick.{Pipeline, Log}
  alias Thunderline.Memory.Manager, as: MemoryManager
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"agent_id" => agent_id} = args} = job) do
    Logger.debug("Starting tick for PAC Agent #{agent_id}")

    # Extract Broadway metadata if available
    broadway_metadata = extract_broadway_metadata(job)

    with {:ok, agent} <- load_agent(agent_id),
         {:ok, context} <- build_tick_context(agent, args),
         {:ok, result} <- Pipeline.execute_tick(agent, context),
         {:ok, _log} <- Log.create_tick_log(agent, result, broadway_metadata) do

      # Notify orchestrator of completion
      notify_tick_completion(agent_id, result)

      Logger.debug("Completed tick for PAC Agent #{agent.name} (#{agent_id})")
      :ok
    else
      {:error, :agent_not_found} ->
        Logger.warning("PAC Agent #{agent_id} not found, skipping tick")
        :ok

      {:error, :agent_inactive} ->
        Logger.info("PAC Agent #{agent_id} is inactive, stopping ticks")
        :ok

      {:error, reason} ->
        Logger.error("Tick failed for PAC Agent #{agent_id}: #{inspect(reason)}")
        notify_tick_failure(agent_id, reason)
        {:error, reason}
    end
  end

  # Private functions

  defp load_agent(agent_id) do
    case Agent.get_by_id(agent_id, load: [:zone, :mods]) do
      {:ok, agent} ->
        # Check if agent is active based on state
        case agent.state do
          %{"activity" => "inactive"} -> {:error, :agent_inactive}
          _ -> {:ok, agent}
        end

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:error, :agent_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_tick_context(agent, args) do
    # Calculate time since last tick
    time_since_last_tick =
      case agent.updated_at do
        nil -> 0
        last_update -> DateTime.diff(DateTime.utc_now(), last_update, :second)
      end

    # Get zone context if agent is in a zone
    zone_context =
      if agent.zone do
        case Zone.get_by_id(agent.zone.id, load: [:agents]) do
          {:ok, zone} ->
            %{
              zone: zone,
              zone_agents: zone.agents,
              zone_properties: zone.properties,
              zone_rules: zone.rules
            }
          _ -> %{}
        end
      else
        %{}
      end

    # Get recent memories
    memory_context =
      case MemoryManager.get_recent_memories(agent.id, limit: 5) do
        {:ok, memories} -> %{recent_memories: memories}
        _ -> %{recent_memories: []}
      end

    # Get active mods affecting the agent
    mod_context = %{
      active_mods: agent.mods || [],
      mod_effects: calculate_mod_effects(agent.mods || [])
    }

    context = %{
      agent_id: agent.id,
      time_since_last_tick: time_since_last_tick,
      tick_number: Map.get(args, "tick_number", 0),
      environment: zone_context,
      memory: memory_context,
      modifications: mod_context,
      timestamp: DateTime.utc_now()
    }

    {:ok, context}
  end

  defp calculate_mod_effects(mods) do
    # Calculate cumulative effects from all active mods
    active_mods = Enum.filter(mods, & &1.active)

    Enum.reduce(active_mods, %{}, fn mod, acc ->
      effects = mod.effects || %{}

      # Merge stat modifiers
      stat_mods = Map.get(effects, "stat_modifiers", %{})
      current_stat_mods = Map.get(acc, :stat_modifiers, %{})
      new_stat_mods = Map.merge(current_stat_mods, stat_mods, fn _k, v1, v2 -> v1 + v2 end)

      # Merge trait modifiers
      trait_mods = Map.get(effects, "trait_modifiers", %{})
      current_trait_mods = Map.get(acc, :trait_modifiers, %{})
      new_trait_mods = Map.merge(current_trait_mods, trait_mods, fn _k, v1, v2 -> v1 + v2 end)

      # Collect capabilities
      new_capabilities = Map.get(effects, "new_capabilities", [])
      current_capabilities = Map.get(acc, :new_capabilities, [])

      # Collect tool access
      tool_access = Map.get(effects, "tool_access", [])
      current_tools = Map.get(acc, :tool_access, [])

      %{
        stat_modifiers: new_stat_mods,
        trait_modifiers: new_trait_mods,
        new_capabilities: current_capabilities ++ new_capabilities,
        tool_access: current_tools ++ tool_access
      }
    end)
  end

  defp extract_broadway_metadata(job) do
    %{
      job_id: job.id,
      queue: job.queue,
      worker: job.worker,
      attempt: job.attempt,
      max_attempts: job.max_attempts,
      scheduled_at: job.scheduled_at,
      attempted_at: job.attempted_at,
      inserted_at: job.inserted_at
    }
  end

  defp notify_tick_completion(agent_id, result) do
    # Send completion notification to orchestrator
    GenServer.cast(Thunderline.Tick.Orchestrator, {:tick_completed, agent_id, result})
  end

  defp notify_tick_failure(agent_id, reason) do
    # Send failure notification to orchestrator
    GenServer.cast(Thunderline.Tick.Orchestrator, {:tick_failed, agent_id, reason})
  end
end
