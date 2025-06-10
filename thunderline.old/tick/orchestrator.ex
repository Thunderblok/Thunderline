defmodule Thunderline.Tick.Orchestrator do
  @moduledoc """
  Tick Orchestrator - Manages and coordinates tick scheduling across all PACs.

  The Orchestrator provides:
  - Global tick scheduling and coordination
  - Load balancing across PAC populations
  - System health monitoring and throttling
  - Batch tick operations for efficiency
  - Analytics and performance monitoring

  This ensures the Thunderline substrate remains responsive and scalable
  even with large numbers of active PACs.
  """

  use GenServer
  require Logger

  alias Thunderline.{PAC, Repo}
  alias Thunderline.Tick.{TickWorker, Log}

  defstruct [
    :active_pacs,
    :tick_schedule,
    :performance_metrics,
    :system_health,
    :config
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def schedule_pac_ticks(pac_id) do
    GenServer.call(__MODULE__, {:schedule_pac_ticks, pac_id})
  end

  def unschedule_pac_ticks(pac_id) do
    GenServer.call(__MODULE__, {:unschedule_pac_ticks, pac_id})
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

  def force_tick_for_pac(pac_id) do
    GenServer.call(__MODULE__, {:force_tick, pac_id})
  end

  # Server Implementation

  @impl true
  def init(opts) do
    config = %{
      max_concurrent_ticks: Keyword.get(opts, :max_concurrent_ticks, 10),
      health_check_interval: Keyword.get(opts, :health_check_interval, 30_000),
      metrics_collection_interval: Keyword.get(opts, :metrics_collection_interval, 60_000),
      auto_throttle: Keyword.get(opts, :auto_throttle, true),
      tick_timeout: Keyword.get(opts, :tick_timeout, 30_000)
    }

    state = %__MODULE__{
      active_pacs: MapSet.new(),
      tick_schedule: %{},
      performance_metrics: init_metrics(),
      system_health: %{status: :healthy, last_check: DateTime.utc_now()},
      config: config
    }

    # Schedule periodic tasks
    schedule_health_check(config.health_check_interval)
    schedule_metrics_collection(config.metrics_collection_interval)

    Logger.info("Tick Orchestrator started with config: #{inspect(config)}")

    {:ok, state, {:continue, :load_active_pacs}}
  end

  @impl true
  def handle_continue(:load_active_pacs, state) do
    # Load all currently active PACs
    active_pac_ids =
      PAC
      |> Ash.Query.filter(not is_nil(last_tick_at))
      |> Ash.Query.select([:id])
      |> Ash.read!(domain: Thunderline.Domain)
      |> Enum.map(& &1.id)
      |> MapSet.new()

    Logger.info("Loaded #{MapSet.size(active_pac_ids)} active PACs for orchestration")

    new_state = %{state | active_pacs: active_pac_ids}
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:schedule_pac_ticks, pac_id}, _from, state) do
    if MapSet.member?(state.active_pacs, pac_id) do
      {:reply, {:ok, :already_scheduled}, state}
    else
      case schedule_initial_tick(pac_id) do
        {:ok, job} ->
          new_active_pacs = MapSet.put(state.active_pacs, pac_id)
          new_tick_schedule = Map.put(state.tick_schedule, pac_id, job.id)

          new_state = %{state |
            active_pacs: new_active_pacs,
            tick_schedule: new_tick_schedule
          }

          Logger.info("Scheduled ticks for PAC #{pac_id}")
          {:reply, {:ok, job}, new_state}

        {:error, reason} ->
          Logger.error("Failed to schedule ticks for PAC #{pac_id}: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  @impl true
  def handle_call({:unschedule_pac_ticks, pac_id}, _from, state) do
    if MapSet.member?(state.active_pacs, pac_id) do
      # Cancel any scheduled jobs for this PAC
      case Map.get(state.tick_schedule, pac_id) do
        nil ->
          :ok
        job_id ->
          case Oban.cancel_job(job_id) do
            {:ok, _} -> Logger.info("Cancelled scheduled tick job for PAC #{pac_id}")
            {:error, reason} -> Logger.warn("Failed to cancel job for PAC #{pac_id}: #{inspect(reason)}")
          end
      end

      new_active_pacs = MapSet.delete(state.active_pacs, pac_id)
      new_tick_schedule = Map.delete(state.tick_schedule, pac_id)

      new_state = %{state |
        active_pacs: new_active_pacs,
        tick_schedule: new_tick_schedule
      }

      Logger.info("Unscheduled ticks for PAC #{pac_id}")
      {:reply, {:ok, :unscheduled}, new_state}
    else
      {:reply, {:ok, :not_scheduled}, state}
    end
  end

  @impl true
  def handle_call(:get_system_status, _from, state) do
    status = %{
      active_pacs: MapSet.size(state.active_pacs),
      scheduled_jobs: map_size(state.tick_schedule),
      system_health: state.system_health,
      performance_metrics: state.performance_metrics,
      config: state.config
    }

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_call(:get_performance_metrics, _from, state) do
    {:reply, {:ok, state.performance_metrics}, state}
  end

  @impl true
  def handle_call(:pause_all_ticks, _from, state) do
    # Cancel all scheduled tick jobs
    cancelled_count =
      Enum.reduce(state.tick_schedule, 0, fn {pac_id, job_id}, acc ->
        case Oban.cancel_job(job_id) do
          {:ok, _} ->
            Logger.debug("Paused ticks for PAC #{pac_id}")
            acc + 1
          {:error, reason} ->
            Logger.warn("Failed to pause ticks for PAC #{pac_id}: #{inspect(reason)}")
            acc
        end
      end)

    new_state = %{state | tick_schedule: %{}}

    Logger.info("Paused ticks for #{cancelled_count} PACs")
    {:reply, {:ok, cancelled_count}, new_state}
  end

  @impl true
  def handle_call(:resume_all_ticks, _from, state) do
    # Reschedule ticks for all active PACs
    {successful, failed} =
      state.active_pacs
      |> Enum.map(fn pac_id ->
        case schedule_initial_tick(pac_id) do
          {:ok, job} -> {:ok, {pac_id, job.id}}
          {:error, reason} -> {:error, {pac_id, reason}}
        end
      end)
      |> Enum.split_with(&match?({:ok, _}, &1))

    new_tick_schedule =
      successful
      |> Enum.map(fn {:ok, {pac_id, job_id}} -> {pac_id, job_id} end)
      |> Map.new()

    new_state = %{state | tick_schedule: new_tick_schedule}

    success_count = length(successful)
    failure_count = length(failed)

    Logger.info("Resumed ticks for #{success_count} PACs, failed for #{failure_count}")

    if failure_count > 0 do
      Logger.warn("Failed to resume ticks: #{inspect(failed)}")
    end

    {:reply, {:ok, {success_count, failure_count}}, new_state}
  end

  @impl true
  def handle_call({:force_tick, pac_id}, _from, state) do
    case force_immediate_tick(pac_id) do
      {:ok, job} ->
        Logger.info("Forced immediate tick for PAC #{pac_id}")
        {:reply, {:ok, job}, state}

      {:error, reason} ->
        Logger.error("Failed to force tick for PAC #{pac_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:health_check, state) do
    new_health = perform_health_check(state)
    new_state = %{state | system_health: new_health}

    # Schedule next health check
    schedule_health_check(state.config.health_check_interval)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:collect_metrics, state) do
    new_metrics = collect_performance_metrics(state)
    new_state = %{state | performance_metrics: new_metrics}

    # Schedule next metrics collection
    schedule_metrics_collection(state.config.metrics_collection_interval)

    {:noreply, new_state}
  end

  # Private implementation functions

  defp schedule_initial_tick(pac_id) do
    %{pac_id: pac_id}
    |> TickWorker.new(schedule_in: :rand.uniform(30) + 5) # Random delay 5-35 seconds
    |> Oban.insert()
  end

  defp force_immediate_tick(pac_id) do
    %{pac_id: pac_id}
    |> TickWorker.new(schedule_in: 1) # 1 second delay
    |> Oban.insert()
  end

  defp schedule_health_check(interval) do
    Process.send_after(self(), :health_check, interval)
  end

  defp schedule_metrics_collection(interval) do
    Process.send_after(self(), :collect_metrics, interval)
  end

  defp perform_health_check(state) do
    # Check Oban job queue health
    queue_stats = get_oban_queue_stats()

    # Check database connectivity
    db_health = check_database_health()

    # Check system resource usage
    system_load = get_system_load()

    # Determine overall health status
    status = determine_health_status(queue_stats, db_health, system_load)

    health = %{
      status: status,
      last_check: DateTime.utc_now(),
      queue_stats: queue_stats,
      db_health: db_health,
      system_load: system_load
    }

    if status != :healthy do
      Logger.warn("System health check failed: #{inspect(health)}")
    else
      Logger.debug("System health check passed")
    end

    health
  end

  defp collect_performance_metrics(state) do
    now = DateTime.utc_now()

    # Get tick performance from recent logs
    tick_metrics = get_recent_tick_metrics()

    # Get queue performance
    queue_metrics = get_queue_performance()

    # Get PAC activity metrics
    pac_metrics = get_pac_activity_metrics(state.active_pacs)

    %{
      timestamp: now,
      tick_metrics: tick_metrics,
      queue_metrics: queue_metrics,
      pac_metrics: pac_metrics,
      active_pac_count: MapSet.size(state.active_pacs),
      scheduled_job_count: map_size(state.tick_schedule)
    }
  end

  defp init_metrics do
    %{
      timestamp: DateTime.utc_now(),
      tick_metrics: %{},
      queue_metrics: %{},
      pac_metrics: %{},
      active_pac_count: 0,
      scheduled_job_count: 0
    }
  end

  defp get_oban_queue_stats do
    try do
      # This would use Oban.check_queue/2 or similar in a real implementation
      %{
        available: 0,
        executing: 0,
        retryable: 0,
        scheduled: 0,
        cancelled: 0
      }
    rescue
      _ -> %{error: "unable_to_fetch_stats"}
    end
  end

  defp check_database_health do
    try do
      case Ecto.Adapters.SQL.query(Repo, "SELECT 1", []) do
        {:ok, _} -> :healthy
        {:error, _} -> :unhealthy
      end
    rescue
      _ -> :unhealthy
    end
  end

  defp get_system_load do
    # This would check actual system metrics in a real implementation
    %{
      cpu_usage: :rand.uniform(100),
      memory_usage: :rand.uniform(100),
      load_average: :rand.uniform() * 4.0
    }
  end

  defp determine_health_status(queue_stats, db_health, system_load) do
    cond do
      db_health != :healthy -> :unhealthy
      Map.has_key?(queue_stats, :error) -> :degraded
      system_load.cpu_usage > 90 -> :degraded
      system_load.memory_usage > 95 -> :degraded
      true -> :healthy
    end
  end

  defp get_recent_tick_metrics do
    since = DateTime.utc_now() |> DateTime.add(-300, :second) # Last 5 minutes

    try do
      logs =
        Log
        |> Ash.Query.filter(inserted_at > ^since)
        |> Ash.read!(domain: Thunderline.Domain)

      if Enum.empty?(logs) do
        %{total_ticks: 0}
      else
        %{
          total_ticks: length(logs),
          average_duration: calculate_average_duration(logs),
          success_rate: calculate_overall_success_rate(logs),
          error_rate: calculate_overall_error_rate(logs)
        }
      end
    rescue
      _ -> %{error: "unable_to_fetch_metrics"}
    end
  end

  defp get_queue_performance do
    # Placeholder for Oban queue performance metrics
    %{
      throughput: :rand.uniform(100),
      average_wait_time: :rand.uniform(1000),
      failure_rate: :rand.uniform() * 0.1
    }
  end

  defp get_pac_activity_metrics(active_pacs) do
    %{
      active_count: MapSet.size(active_pacs),
      # Additional PAC-specific metrics would go here
    }
  end

  defp calculate_average_duration(logs) do
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

  defp calculate_overall_success_rate(logs) do
    if Enum.empty?(logs) do
      0.0
    else
      total_rate =
        logs
        |> Enum.map(& Decimal.to_float(&1.action_success_rate || Decimal.new(0)))
        |> Enum.sum()

      total_rate / length(logs)
    end
  end

  defp calculate_overall_error_rate(logs) do
    if Enum.empty?(logs) do
      0.0
    else
      logs_with_errors = Enum.count(logs, &(!Enum.empty?(&1.errors)))
      logs_with_errors / length(logs)
    end
  end
end
