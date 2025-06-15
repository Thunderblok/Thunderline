defmodule Thunderline.Tick.Orchestrator do
  @moduledoc """
  Tick Orchestrator - Manages and coordinates tick scheduling across all PAC Agents.

  The Orchestrator provides:
  - Global tick scheduling and coordination
  - Load balancing across PAC Agent populations
  - System health monitoring and throttling
  - Batch tick operations for efficiency
  - Analytics and performance monitoring

  This ensures the Thunderline substrate remains responsive and scalable
  even with large numbers of active PAC Agents.
  """

  use GenServer
  require Logger

  alias Thunderline.PAC.{Agent, Manager}
  alias Thunderline.Tick.{TickWorker, Log}

  defstruct [
    :active_agents,
    :tick_schedule,
    :performance_metrics,
    :system_health,
    :config
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def schedule_agent_ticks(agent_id) do
    GenServer.call(__MODULE__, {:schedule_agent_ticks, agent_id})
  end

  def unschedule_agent_ticks(agent_id) do
    GenServer.call(__MODULE__, {:unschedule_agent_ticks, agent_id})
  end

  def get_system_status do
    GenServer.call(__MODULE__, :get_system_status)
  end

  def get_performance_metrics do
    GenServer.call(__MODULE__, :get_performance_metrics)
  end

  def pause_all_ticks do
    GenServer.call(__MODULE__, :pause_all_ticks)
  end

  def resume_all_ticks do
    GenServer.call(__MODULE__, :resume_all_ticks)
  end

  def force_tick_for_agent(agent_id) do
    GenServer.call(__MODULE__, {:force_tick, agent_id})
  end

  # Server Implementation

  @impl true
  def init(opts) do
    config = %{
      max_concurrent_ticks: Keyword.get(opts, :max_concurrent_ticks, 10),
      health_check_interval: Keyword.get(opts, :health_check_interval, 30_000),
      metrics_collection_interval: Keyword.get(opts, :metrics_collection_interval, 60_000),
      auto_throttle: Keyword.get(opts, :auto_throttle, true),
      tick_timeout: Keyword.get(opts, :tick_timeout, 30_000),
      tick_interval: Application.get_env(:thunderline, :pac)[:tick_interval] || 30_000
    }

    state = %__MODULE__{
      active_agents: MapSet.new(),
      tick_schedule: %{},
      performance_metrics: init_metrics(),
      system_health: %{status: :healthy, last_check: DateTime.utc_now()},
      config: config
    }

    # Schedule periodic tasks
    schedule_health_check(config.health_check_interval)
    schedule_metrics_collection(config.metrics_collection_interval)

    Logger.info("Tick Orchestrator started with config: #{inspect(config)}")

    {:ok, state, {:continue, :load_active_agents}}
  end

  @impl true
  def handle_continue(:load_active_agents, state) do
    # Load all currently active PAC Agents
    case Agent.list_active() do
      {:ok, active_agents} ->
        active_agent_ids = MapSet.new(active_agents, & &1.id)

        Logger.info(
          "Loaded #{MapSet.size(active_agent_ids)} active agents for tick orchestration"
        )

        # Schedule ticks for all active agents
        Enum.each(active_agent_ids, fn agent_id ->
          schedule_agent_tick(agent_id, state.config.tick_interval)
        end)

        new_state = %{state | active_agents: active_agent_ids}
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to load active agents: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_call({:schedule_agent_ticks, agent_id}, _from, state) do
    case MapSet.member?(state.active_agents, agent_id) do
      true ->
        {:reply, {:ok, :already_scheduled}, state}

      false ->
        # Add to active agents and schedule tick
        new_active_agents = MapSet.put(state.active_agents, agent_id)
        schedule_agent_tick(agent_id, state.config.tick_interval)

        new_state = %{state | active_agents: new_active_agents}

        Logger.info("Scheduled ticks for agent #{agent_id}")
        {:reply, {:ok, :scheduled}, new_state}
    end
  end

  @impl true
  def handle_call({:unschedule_agent_ticks, agent_id}, _from, state) do
    case MapSet.member?(state.active_agents, agent_id) do
      false ->
        {:reply, {:ok, :not_scheduled}, state}

      true ->
        # Remove from active agents and cancel scheduled tick
        new_active_agents = MapSet.delete(state.active_agents, agent_id)
        cancel_agent_tick(agent_id)

        new_state = %{state | active_agents: new_active_agents}

        Logger.info("Unscheduled ticks for agent #{agent_id}")
        {:reply, {:ok, :unscheduled}, new_state}
    end
  end

  @impl true
  def handle_call(:get_system_status, _from, state) do
    status = %{
      active_agents: MapSet.size(state.active_agents),
      system_health: state.system_health,
      config: state.config,
      uptime: calculate_uptime()
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call(:get_performance_metrics, _from, state) do
    {:reply, state.performance_metrics, state}
  end

  @impl true
  def handle_call(:pause_all_ticks, _from, state) do
    # Cancel all scheduled ticks
    Enum.each(state.active_agents, &cancel_agent_tick/1)

    new_state = %{state | system_health: Map.put(state.system_health, :status, :paused)}

    Logger.info("All ticks paused")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:resume_all_ticks, _from, state) do
    # Reschedule all active agent ticks
    Enum.each(state.active_agents, fn agent_id ->
      schedule_agent_tick(agent_id, state.config.tick_interval)
    end)

    new_state = %{state | system_health: Map.put(state.system_health, :status, :healthy)}

    Logger.info("All ticks resumed")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:force_tick, agent_id}, _from, state) do
    # Execute immediate tick for specified agent
    case execute_agent_tick(agent_id) do
      {:ok, result} ->
        Logger.info("Forced tick completed for agent #{agent_id}")
        {:reply, {:ok, result}, state}

      {:error, reason} ->
        Logger.error("Forced tick failed for agent #{agent_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:health_check, state) do
    # Perform system health check
    health_status = perform_health_check(state)

    new_state = %{
      state
      | system_health:
          Map.merge(state.system_health, %{
            status: health_status,
            last_check: DateTime.utc_now()
          })
    }

    # Schedule next health check
    schedule_health_check(state.config.health_check_interval)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:collect_metrics, state) do
    # Collect performance metrics
    metrics = collect_performance_metrics(state)

    new_state = %{state | performance_metrics: metrics}

    # Schedule next metrics collection
    schedule_metrics_collection(state.config.metrics_collection_interval)

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:tick_completed, agent_id, result}, state) do
    # Handle tick completion notification
    Log.record_tick_completion(agent_id, result)

    # Update performance metrics
    new_metrics = update_tick_metrics(state.performance_metrics, agent_id, result)

    # Schedule next tick for this agent
    schedule_agent_tick(agent_id, state.config.tick_interval)

    {:noreply, %{state | performance_metrics: new_metrics}}
  end

  @impl true
  def handle_info({:tick_failed, agent_id, reason}, state) do
    # Handle tick failure
    Logger.warning("Tick failed for agent #{agent_id}: #{inspect(reason)}")
    Log.record_tick_failure(agent_id, reason)

    # Update error metrics
    new_metrics = update_error_metrics(state.performance_metrics, agent_id, reason)

    # Reschedule tick with potential backoff
    backoff_interval = calculate_backoff_interval(agent_id, state.config.tick_interval)
    schedule_agent_tick(agent_id, backoff_interval)

    {:noreply, %{state | performance_metrics: new_metrics}}
  end

  # Private Functions

  defp init_metrics do
    %{
      total_ticks: 0,
      successful_ticks: 0,
      failed_ticks: 0,
      average_tick_duration: 0.0,
      last_metrics_reset: DateTime.utc_now()
    }
  end

  defp schedule_agent_tick(agent_id, interval) do
    # Use Oban to schedule the tick job
    %{agent_id: agent_id}
    |> TickWorker.new(schedule_in: div(interval, 1000))
    |> Oban.insert()
  end

  defp cancel_agent_tick(agent_id) do
    # Cancel any pending tick jobs for this agent
    Oban.cancel_all_jobs(%{worker: TickWorker, args: %{agent_id: agent_id}})
  end

  defp execute_agent_tick(agent_id) do
    # Execute tick immediately via PAC Manager
    Manager.tick_agent(agent_id)
  end

  defp schedule_health_check(interval) do
    Process.send_after(self(), :health_check, interval)
  end

  defp schedule_metrics_collection(interval) do
    Process.send_after(self(), :collect_metrics, interval)
  end

  defp perform_health_check(state) do
    # Check system resources, database connectivity, etc.
    cond do
      MapSet.size(state.active_agents) > 1000 ->
        :overloaded

      state.performance_metrics.failed_ticks / max(state.performance_metrics.total_ticks, 1) > 0.1 ->
        :degraded

      true ->
        :healthy
    end
  end

  defp collect_performance_metrics(state) do
    # Collect current performance data
    # This would integrate with telemetry in a real implementation
    state.performance_metrics
  end

  defp update_tick_metrics(metrics, _agent_id, _result) do
    %{
      metrics
      | total_ticks: metrics.total_ticks + 1,
        successful_ticks: metrics.successful_ticks + 1
    }
  end

  defp update_error_metrics(metrics, _agent_id, _reason) do
    %{metrics | total_ticks: metrics.total_ticks + 1, failed_ticks: metrics.failed_ticks + 1}
  end

  defp calculate_backoff_interval(_agent_id, base_interval) do
    # Simple exponential backoff - could be more sophisticated
    base_interval * 2
  end

  defp calculate_uptime do
    # Calculate orchestrator uptime
    System.monotonic_time(:second)
  end
end
