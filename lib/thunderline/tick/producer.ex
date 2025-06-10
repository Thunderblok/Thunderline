defmodule Thunderline.Tick.Producer do
  @moduledoc """
  Broadway producer for generating tick events.

  This GenStage producer generates tick events for active agents based on:
  - Global tick interval
  - Agent-specific tick schedules
  - System load and health
  - Priority-based scheduling

  It integrates with the PAC Manager to discover active agents and
  coordinates with the tick orchestrator for system-wide scheduling.
  """

  use GenStage
  require Logger

  alias Thunderline.PAC.{Agent, Manager}

  @default_tick_interval 30_000  # 30 seconds
  @batch_size 20

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    tick_interval = Keyword.get(opts, :tick_interval, @default_tick_interval)

    # Schedule the first tick
    schedule_tick(tick_interval)

    state = %{
      tick_interval: tick_interval,
      tick_count: 0,
      demand: 0,
      buffer: []
    }

    Logger.info("Tick Producer started with #{tick_interval}ms interval")

    {:producer, state}
  end

  def handle_demand(incoming_demand, %{demand: demand} = state) do
    total_demand = demand + incoming_demand

    # If we have events in buffer, dispatch them
    {events, remaining_buffer} = Enum.split(state.buffer, total_demand)
    remaining_demand = total_demand - length(events)

    new_state = %{state |
      demand: remaining_demand,
      buffer: remaining_buffer
    }

    {:noreply, events, new_state}
  end

  def handle_info(:tick, state) do
    Logger.debug("Generating tick events for active agents")

    # Generate tick events for all active agents
    tick_events = generate_tick_events(state.tick_count)

    # Add events to buffer
    new_buffer = state.buffer ++ tick_events

    # Dispatch events if there's demand
    {events_to_send, remaining_buffer} = Enum.split(new_buffer, state.demand)
    remaining_demand = state.demand - length(events_to_send)

    # Schedule next tick
    schedule_tick(state.tick_interval)

    new_state = %{state |
      tick_count: state.tick_count + 1,
      demand: remaining_demand,
      buffer: remaining_buffer
    }

    # Emit telemetry
    :telemetry.execute([:thunderline, :tick, :generated], %{
      count: length(tick_events),
      tick_number: state.tick_count
    })

    {:noreply, events_to_send, new_state}
  end

  def handle_info({:tick_agent, agent_id}, state) do
    # Handle individual agent tick requests
    tick_event = create_tick_event(agent_id, state.tick_count)

    new_buffer = state.buffer ++ [tick_event]

    # Dispatch if there's demand
    {events_to_send, remaining_buffer} = Enum.split(new_buffer, state.demand)
    remaining_demand = state.demand - length(events_to_send)

    new_state = %{state |
      demand: remaining_demand,
      buffer: remaining_buffer
    }

    {:noreply, events_to_send, new_state}
  end

  # Public API for external tick requests
  def tick_agent(agent_id) do
    send(__MODULE__, {:tick_agent, agent_id})
  end

  # Private Functions

  defp generate_tick_events(tick_count) do
    case get_active_agents() do
      {:ok, agents} ->
        Logger.debug("Generating ticks for #{length(agents)} active agents")

        agents
        |> Enum.map(&create_tick_event(&1.id, tick_count))
        |> add_system_context(tick_count)

      {:error, reason} ->
        Logger.error("Failed to get active agents: #{inspect(reason)}")
        []
    end
  end

  defp get_active_agents do
    case Agent.list_active() do
      {:ok, agents} -> {:ok, agents}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_tick_event(agent_id, tick_count) do
    %{
      agent_id: agent_id,
      context: %{
        tick_count: tick_count,
        timestamp: DateTime.utc_now(),
        system_load: get_system_load(),
        global_context: get_global_context()
      }
    }
  end

  defp add_system_context(events, tick_count) do
    # Add system-wide context that might affect all agents
    system_context = %{
      global_tick_count: tick_count,
      system_health: get_system_health(),
      active_agent_count: length(events)
    }

    Enum.map(events, fn event ->
      put_in(event.context.system_context, system_context)
    end)
  end

  defp get_system_load do
    # Simple system load calculation
    %{
      memory_usage: get_memory_usage(),
      cpu_usage: get_cpu_usage(),
      process_count: length(Process.list())
    }
  end

  defp get_memory_usage do
    case :erlang.memory() do
      memory_info when is_list(memory_info) ->
        total = Keyword.get(memory_info, :total, 0)
        div(total, 1024 * 1024)  # Convert to MB

      _ -> 0
    end
  end

  defp get_cpu_usage do
    # Simplified CPU usage (would need more sophisticated monitoring in production)
    scheduler_count = System.schedulers_online()
    %{schedulers: scheduler_count}
  end

  defp get_system_health do
    # Basic system health indicators
    %{
      status: :healthy,
      uptime: System.system_time(:second),
      vm_status: :running
    }
  end

  defp get_global_context do
    # Global context that might affect agent behavior
    %{
      time_of_day: get_time_of_day(),
      day_of_week: Date.day_of_week(Date.utc_today()),
      season: get_season()
    }
  end

  defp get_time_of_day do
    hour = DateTime.utc_now().hour

    cond do
      hour >= 6 and hour < 12 -> :morning
      hour >= 12 and hour < 18 -> :afternoon
      hour >= 18 and hour < 22 -> :evening
      true -> :night
    end
  end

  defp get_season do
    month = Date.utc_today().month

    cond do
      month in [12, 1, 2] -> :winter
      month in [3, 4, 5] -> :spring
      month in [6, 7, 8] -> :summer
      month in [9, 10, 11] -> :autumn
    end
  end

  defp schedule_tick(interval) do
    Process.send_after(self(), :tick, interval)
  end
end
