# ☤ Tick Log Resource - Agent Evolution Tracking System
defmodule Thunderline.Tick.Log do
  @moduledoc """
  Tick Log - Records and tracks the evolution history of PAC Agents. ☤

  Each tick log entry captures: ☤
  - The decisions made by the PAC Agent
  - Actions taken and their outcomes
  - State and stat changes
  - Environmental context
  - AI reasoning process
  - Narrative description
  - Federation metadata for cross-node analysis

  Tick logs serve multiple purposes:
  - Debugging and monitoring PAC Agent behavior
  - Training data for improving AI reasoning
  - Historical playback and analysis
  - Continuity for narrative generation
  - Performance metrics and optimization
  - Federation analytics and cross-node insights
  """

  require Logger

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "tick_logs"
    repo Thunderline.Repo

    custom_indexes do
      index [:agent_id, :tick_number]
      index [:agent_id, :inserted_at]
      index [:decision], using: "gin"
      index [:state_changes], using: "gin"
      index [:node_id, :inserted_at] # Federation support
    end
  end

  attributes do
    uuid_primary_key :id

    # Reference to the PAC Agent
    attribute :agent_id, :uuid do
      allow_nil? false
    end

    # Federation metadata
    attribute :node_id, :string do
      description "Supervisor node where this tick was executed"
    end

    attribute :federation_context, :map do
      default %{}
      description "Cross-node context and metadata"
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

    # Broadway processing metadata
    attribute :broadway_metadata, :map do
      default %{}
      description "Broadway pipeline processing metadata"
    end

    timestamps()
  end

  relationships do
    belongs_to :agent, Thunderline.PAC.Agent do
      source_attribute :agent_id
      destination_attribute :id
    end
  end

  actions do
    defaults [:read]

    create :create_tick_log do
      accept [
        :agent_id, :node_id, :federation_context, :tick_number,
        :tick_duration_ms, :time_since_last_tick, :decision, :reasoning,
        :actions_taken, :action_success_rate, :state_changes, :stat_changes,
        :zone_context, :social_context, :memories_formed, :narrative,
        :ai_response_time_ms, :pipeline_stage_times, :errors, :broadway_metadata
      ]
    end

    read :for_agent do
      argument :agent_id, :uuid, allow_nil?: false
      filter expr(agent_id == ^arg(:agent_id))
    end

    read :for_node do
      argument :node_id, :string, allow_nil?: false
      filter expr(node_id == ^arg(:node_id))
    end

    read :recent do
      argument :limit, :integer, default: 50
    end

    read :for_agent_recent do
      argument :agent_id, :uuid, allow_nil?: false
      argument :limit, :integer, default: 20
      filter expr(agent_id == ^arg(:agent_id))
    end

    read :with_errors do
      filter expr(fragment("array_length(?, 1) > 0", errors))
    end

    read :successful_ticks do
      filter expr(array_length(errors) == 0 and action_success_rate > 0.5)
    end

    read :federation_analytics do
      argument :days_back, :integer, default: 7
      filter expr(inserted_at > ago(^arg(:days_back), "day"))
    end
  end

  # Public interface for creating tick logs

  def create_tick_log(agent, tick_result, broadway_metadata \\ %{}) do
    start_time = System.monotonic_time(:millisecond)

    attrs = %{
      agent_id: agent.id,
      node_id: get_node_id(),
      federation_context: get_federation_context(),
      tick_number: agent.tick_count + 1,
      decision: tick_result.decision,
      reasoning: extract_reasoning(tick_result.decision),
      actions_taken: tick_result.actions_taken,
      action_success_rate: calculate_success_rate(tick_result.actions_taken),
      state_changes: tick_result.state_changes,
      stat_changes: tick_result.stat_changes,
      memories_formed: length(tick_result.new_memories),
      narrative: tick_result.narrative,
      errors: extract_errors(tick_result),
      broadway_metadata: broadway_metadata
    }

    end_time = System.monotonic_time(:millisecond)
    final_attrs = Map.put(attrs, :tick_duration_ms, end_time - start_time)

    case __MODULE__
         |> Ash.Changeset.for_create(:create_tick_log, final_attrs)
         |> Ash.create(domain: Thunderline.Domain) do
      {:ok, log} ->
        Logger.debug("Created tick log for Agent #{agent.name}, tick ##{log.tick_number}")
        {:ok, log}

      {:error, error} ->
        Logger.error("Failed to create tick log for Agent #{agent.name}: #{inspect(error)}")
        {:error, error}
    end
  end

  # Analysis and metrics functions
  def get_agent_metrics(agent_id, days_back \\ 7) do
    since_date = DateTime.utc_now() |> DateTime.add(-days_back, :day)

    logs =
      __MODULE__
      |> Ash.Query.filter(agent_id == agent_id)
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
        active_days: count_active_days(logs),
        federation_stats: get_federation_stats(logs)
      }

      {:ok, metrics}
    end
  end
  def get_node_metrics(node_id, days_back \\ 7) do
    since_date = DateTime.utc_now() |> DateTime.add(-days_back, :day)

    logs =
      __MODULE__
      |> Ash.Query.filter(node_id == node_id)
      |> Ash.read!(domain: Thunderline.Domain)

    if Enum.empty?(logs) do
      {:ok, %{total_ticks: 0, message: "No ticks in the specified period"}}
    else
      metrics = %{
        total_ticks: length(logs),
        unique_agents: count_unique_agents(logs),
        average_success_rate: calculate_average_success_rate(logs),
        throughput_per_hour: calculate_throughput(logs),
        error_rate: calculate_error_rate(logs),
        average_tick_duration: calculate_average_tick_duration(logs)
      }

      {:ok, metrics}
    end
  end
  def get_narrative_timeline(agent_id, limit \\ 10) do
    __MODULE__
    |> Ash.Query.filter(agent_id == agent_id)
    |> Ash.Query.sort(tick_number: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.read!(domain: Thunderline.Domain)
    |> Enum.map(fn log ->
      %{
        tick_number: log.tick_number,
        timestamp: log.inserted_at,
        narrative: log.narrative,
        actions: Enum.map(log.actions_taken, & &1["action"]),
        mood: get_in(log.state_changes, ["mood"]),
        node_id: log.node_id
      }
    end)
  end

  # Federation analytics
  def get_federation_analytics(days_back \\ 7) do
    __MODULE__
    |> Ash.Query.for_read(:federation_analytics, %{days_back: days_back})
    |> Ash.read!(domain: Thunderline.Domain)
    |> analyze_federation_patterns()
  end

  # Private helper functions

  defp get_node_id do
    # Get current supervisor node ID - will be configured per deployment
    Application.get_env(:thunderline, :node_id, "default_node")
  end

  defp get_federation_context do
    %{
      node_version: Application.spec(:thunderline, :vsn),
      elixir_version: System.version(),
      timestamp: DateTime.utc_now()
    }
  end

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

  defp count_unique_agents(logs) do
    logs
    |> Enum.map(& &1.agent_id)
    |> Enum.uniq()
    |> length()
  end

  defp calculate_throughput(logs) do
    if Enum.empty?(logs) do
      0.0
    else
      time_span_hours =
        logs
        |> Enum.map(& &1.inserted_at)
        |> Enum.min_max()
        |> then(fn {min_time, max_time} ->
          DateTime.diff(max_time, min_time, :hour)
        end)
        |> max(1) # Minimum 1 hour to avoid division by zero

      length(logs) / time_span_hours
    end
  end

  defp get_federation_stats(logs) do
    %{
      cross_node_interactions: count_cross_node_interactions(logs),
      node_distribution: get_node_distribution(logs),
      federation_events: count_federation_events(logs)
    }
  end

  defp count_cross_node_interactions(logs) do
    logs
    |> Enum.count(fn log ->
      !Enum.empty?(Map.get(log.federation_context, "cross_node_interactions", []))
    end)
  end

  defp get_node_distribution(logs) do
    logs
    |> Enum.map(& &1.node_id)
    |> Enum.frequencies()
  end

  defp count_federation_events(logs) do
    logs
    |> Enum.flat_map(fn log ->
      Map.get(log.federation_context, "federation_events", [])
    end)
    |> length()
  end

  defp analyze_federation_patterns(logs) do
    %{
      total_logs: length(logs),
      node_performance: analyze_node_performance(logs),
      cross_node_patterns: analyze_cross_node_patterns(logs),
      load_distribution: analyze_load_distribution(logs),
      federation_health: assess_federation_health(logs)
    }
  end

  defp analyze_node_performance(logs) do
    logs
    |> Enum.group_by(& &1.node_id)
    |> Enum.map(fn {node_id, node_logs} ->
      {node_id, %{
        tick_count: length(node_logs),
        average_duration: calculate_average_tick_duration(node_logs),
        success_rate: calculate_average_success_rate(node_logs),
        error_rate: calculate_error_rate(node_logs)
      }}
    end)
    |> Map.new()
  end

  defp analyze_cross_node_patterns(logs) do
    # Analyze patterns in cross-node interactions
    %{
      migration_count: count_migrations(logs),
      collaboration_events: count_collaborations(logs),
      resource_sharing: count_resource_sharing(logs)
    }
  end

  defp analyze_load_distribution(logs) do
    node_loads = get_node_distribution(logs)
    total_load = Enum.sum(Map.values(node_loads))

    if total_load > 0 do
      node_loads
      |> Enum.map(fn {node_id, load} ->
        {node_id, load / total_load}
      end)
      |> Map.new()
    else
      %{}
    end
  end

  defp assess_federation_health(logs) do
    recent_logs =
      logs
      |> Enum.filter(fn log ->
        DateTime.diff(DateTime.utc_now(), log.inserted_at, :hour) <= 1
      end)

    %{
      recent_activity: length(recent_logs),
      error_rate_last_hour: calculate_error_rate(recent_logs),
      nodes_active: recent_logs |> Enum.map(& &1.node_id) |> Enum.uniq() |> length(),
      health_status: determine_federation_health_status(recent_logs)
    }
  end

  defp count_migrations(logs) do
    logs
    |> Enum.count(fn log ->
      actions = Enum.map(log.actions_taken, & &1["action"])
      "migrate" in actions or "transfer" in actions
    end)
  end

  defp count_collaborations(logs) do
    logs
    |> Enum.count(fn log ->
      actions = Enum.map(log.actions_taken, & &1["action"])
      "collaborate" in actions or "interact" in actions
    end)
  end

  defp count_resource_sharing(logs) do
    logs
    |> Enum.count(fn log ->
      Map.has_key?(log.federation_context, "resource_sharing")
    end)
  end

  defp determine_federation_health_status(recent_logs) do
    cond do
      Enum.empty?(recent_logs) -> :inactive
      calculate_error_rate(recent_logs) > 0.2 -> :degraded
      length(recent_logs) < 5 -> :low_activity
      true -> :healthy
    end
  end
end
