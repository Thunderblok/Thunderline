defmodule Thunderline.Tick.Log do
  @moduledoc """
  Tick Log - Records and tracks the evolution history of PACs.

  Each tick log entry captures:
  - The decisions made by the PAC
  - Actions taken and their outcomes
  - State and stat changes
  - Environmental context
  - AI reasoning process
  - Narrative description

  Tick logs serve multiple purposes:
  - Debugging and monitoring PAC behavior
  - Training data for improving AI reasoning
  - Historical playback and analysis
  - Continuity for narrative generation
  - Performance metrics and optimization
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "tick_logs"
    repo Thunderline.Repo

    custom_indexes do
      index [:pac_id, :tick_number]
      index [:pac_id, :inserted_at]
      index [:decision], using: :gin
      index [:state_changes], using: :gin
    end
  end

  attributes do
    uuid_primary_key :id

    # Reference to the PAC
    attribute :pac_id, :uuid do
      allow_nil? false
    end

    # Tick identification
    attribute :tick_number, :integer do
      allow_nil? false
    end

    # Tick timing
    attribute :tick_duration_ms, :integer
    attribute :time_since_last_tick, :integer # seconds

    # Decision and reasoning data
    attribute :decision, :map do
      default %{}
    end

    attribute :reasoning, :string do
      constraints max_length: 2000
    end

    # Actions and outcomes
    attribute :actions_taken, {:array, :map} do
      default []
    end

    attribute :action_success_rate, :decimal do
      constraints min: 0.0, max: 1.0
    end

    # State changes
    attribute :state_changes, :map do
      default %{}
    end

    attribute :stat_changes, :map do
      default %{}
    end

    # Context information
    attribute :zone_context, :map do
      default %{}
    end

    attribute :social_context, :map do
      default %{}
    end

    # Memory and narrative
    attribute :memories_formed, :integer, default: 0
    attribute :narrative, :string

    # Performance metrics
    attribute :ai_response_time_ms, :integer
    attribute :pipeline_stage_times, :map do
      default %{}
    end

    # Error tracking
    attribute :errors, {:array, :map} do
      default []
    end

    timestamps()
  end

  relationships do
    belongs_to :pac, Thunderline.PAC do
      source_attribute :pac_id
      destination_attribute :id
    end
  end

  actions do
    defaults [:read]

    create :create_tick_log do
      accept [
        :pac_id, :tick_number, :tick_duration_ms, :time_since_last_tick,
        :decision, :reasoning, :actions_taken, :action_success_rate,
        :state_changes, :stat_changes, :zone_context, :social_context,
        :memories_formed, :narrative, :ai_response_time_ms,
        :pipeline_stage_times, :errors
      ]
    end

    read :for_pac do
      argument :pac_id, :uuid, allow_nil?: false
      filter expr(pac_id == ^arg(:pac_id))
    end

    read :recent do
      argument :limit, :integer, default: 50
      sort inserted_at: :desc
    end

    read :for_pac_recent do
      argument :pac_id, :uuid, allow_nil?: false
      argument :limit, :integer, default: 20

      filter expr(pac_id == ^arg(:pac_id))
      sort inserted_at: :desc
    end

    read :with_errors do
      filter expr(fragment("array_length(?, 1) > 0", errors))
    end

    read :successful_ticks do
      filter expr(array_length(errors) == 0 and action_success_rate > 0.5)
    end
  end

  # Public interface for creating tick logs

  def create_tick_log(pac, tick_result) do
    start_time = System.monotonic_time(:millisecond)

    attrs = %{
      pac_id: pac.id,
      tick_number: pac.tick_count + 1,
      decision: tick_result.decision,
      reasoning: extract_reasoning(tick_result.decision),
      actions_taken: tick_result.actions_taken,
      action_success_rate: calculate_success_rate(tick_result.actions_taken),
      state_changes: tick_result.state_changes,
      stat_changes: tick_result.stat_changes,
      memories_formed: length(tick_result.new_memories),
      narrative: tick_result.narrative,
      errors: extract_errors(tick_result)
    }

    end_time = System.monotonic_time(:millisecond)
    final_attrs = Map.put(attrs, :tick_duration_ms, end_time - start_time)

    case __MODULE__
         |> Ash.Changeset.for_create(:create_tick_log, final_attrs)
         |> Ash.create(domain: Thunderline.Domain) do
      {:ok, log} ->
        Logger.debug("Created tick log for PAC #{pac.name}, tick ##{log.tick_number}")
        {:ok, log}

      {:error, error} ->
        Logger.error("Failed to create tick log for PAC #{pac.name}: #{inspect(error)}")
        {:error, error}
    end
  end

  # Analysis and metrics functions

  def get_pac_metrics(pac_id, days_back \\ 7) do
    since_date = DateTime.utc_now() |> DateTime.add(-days_back, :day)

    logs =
      __MODULE__
      |> Ash.Query.filter(pac_id == ^pac_id and inserted_at > ^since_date)
      |> Ash.read!(domain: Thunderline.Domain)

    if Enum.empty?(logs) do
      {:ok, %{total_ticks: 0, message: "No ticks in the specified period"}}
    else
      metrics = %{
        total_ticks: length(logs),
        average_success_rate: calculate_average_success_rate(logs),
        most_common_actions: get_most_common_actions(logs),
        mood_distribution: get_mood_distribution(logs),
        error_rate: calculate_error_rate(logs),
        average_tick_duration: calculate_average_tick_duration(logs),
        active_days: count_active_days(logs)
      }

      {:ok, metrics}
    end
  end

  def get_narrative_timeline(pac_id, limit \\ 10) do
    __MODULE__
    |> Ash.Query.filter(pac_id == ^pac_id and not is_nil(narrative))
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.read!(domain: Thunderline.Domain)
    |> Enum.map(fn log ->
      %{
        tick_number: log.tick_number,
        timestamp: log.inserted_at,
        narrative: log.narrative,
        actions: Enum.map(log.actions_taken, & &1["action"]),
        mood: get_in(log.state_changes, ["mood"])
      }
    end)
  end

  # Private helper functions

  defp extract_reasoning(decision) do
    Map.get(decision, "reasoning", "No reasoning provided")
  end

  defp calculate_success_rate(actions) when is_list(actions) do
    if Enum.empty?(actions) do
      0.0
    else
      successful_count = Enum.count(actions, & Map.get(&1, "success", false))
      Decimal.from_float(successful_count / length(actions))
    end
  end
  defp calculate_success_rate(_), do: 0.0

  defp extract_errors(tick_result) do
    # Extract any errors from the tick result
    errors = []

    # Check for action failures
    action_errors =
      tick_result.actions_taken
      |> Enum.filter(& !Map.get(&1, "success", true))
      |> Enum.map(fn action ->
        %{
          type: "action_failure",
          action: Map.get(action, "action"),
          reason: Map.get(action, "reason", "unknown"),
          timestamp: DateTime.utc_now()
        }
      end)

    errors ++ action_errors
  end

  defp calculate_average_success_rate(logs) do
    if Enum.empty?(logs) do
      0.0
    else
      total = Enum.reduce(logs, Decimal.new(0), fn log, acc ->
        Decimal.add(acc, log.action_success_rate || Decimal.new(0))
      end)

      Decimal.div(total, length(logs))
      |> Decimal.to_float()
    end
  end

  defp get_most_common_actions(logs) do
    logs
    |> Enum.flat_map(& &1.actions_taken)
    |> Enum.map(& Map.get(&1, "action", "unknown"))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_action, count} -> count end, :desc)
    |> Enum.take(5)
  end

  defp get_mood_distribution(logs) do
    logs
    |> Enum.map(& get_in(&1.state_changes, ["mood"]))
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
  end

  defp calculate_error_rate(logs) do
    logs_with_errors = Enum.count(logs, &(!Enum.empty?(&1.errors)))

    if Enum.empty?(logs) do
      0.0
    else
      logs_with_errors / length(logs)
    end
  end

  defp calculate_average_tick_duration(logs) do
    durations =
      logs
      |> Enum.map(& &1.tick_duration_ms)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(durations) do
      0
    else
      Enum.sum(durations) / length(durations)
    end
  end

  defp count_active_days(logs) do
    logs
    |> Enum.map(& DateTime.to_date(&1.inserted_at))
    |> Enum.uniq()
    |> length()
  end
end
