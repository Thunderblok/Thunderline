defmodule Thunderline.PAC.Manager do
  @moduledoc """
  PAC Manager - Coordinates PAC agents and their interactions.

  The PAC Manager is responsible for:
  - Agent lifecycle management
  - Tick processing coordination
  - Inter-agent communication
  - Zone management
  - Mod application and management
  """

  use GenServer
  require Logger

  alias Thunderline.PAC.{Agent, Zone, Mod}
  alias Thunderline.Domain

  @tick_interval Application.compile_env(:thunderline, [:pac, :tick_interval], 30_000)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Schedule the first tick
    schedule_tick()

    state = %{
      active_agents: MapSet.new(),
      tick_count: 0,
      last_tick: DateTime.utc_now()
    }

    Logger.info("PAC Manager started with #{@tick_interval}ms tick interval")
    {:ok, state}
  end

  # Client API

  @doc """
  Create a new PAC agent in the specified zone.
  """
  def create_agent(name, zone_id, opts \\ []) do
    GenServer.call(__MODULE__, {:create_agent, name, zone_id, opts})
  end

  @doc """
  Get agent by ID with full context.
  """
  def get_agent(agent_id) do
    GenServer.call(__MODULE__, {:get_agent, agent_id})
  end

  @doc """
  Update agent properties.
  """
  def update_agent(agent_id, changes) do
    GenServer.call(__MODULE__, {:update_agent, agent_id, changes})
  end

  @doc """
  Apply a mod to an agent.
  """
  def apply_mod(agent_id, mod_name, mod_type, config \\ %{}) do
    GenServer.call(__MODULE__, {:apply_mod, agent_id, mod_name, mod_type, config})
  end

  @doc """
  Force a tick for a specific agent.
  """
  def tick_agent(agent_id) do
    GenServer.call(__MODULE__, {:tick_agent, agent_id})
  end

  @doc """
  Get current PAC system status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # Server Callbacks

  def handle_call({:create_agent, name, zone_id, opts}, _from, state) do
    case create_agent_impl(name, zone_id, opts) do
      {:ok, agent} ->
        new_state = %{state |
          active_agents: MapSet.put(state.active_agents, agent.id)
        }
        {:reply, {:ok, agent}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_agent, agent_id}, _from, state) do
    case Agent.get_by_id(agent_id, load: [:zone, :mods]) do
      {:ok, agent} -> {:reply, {:ok, agent}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:update_agent, agent_id, changes}, _from, state) do
    case Agent.get_by_id(agent_id) do
      {:ok, agent} ->
        case Agent.update(agent, changes) do
          {:ok, updated_agent} -> {:reply, {:ok, updated_agent}, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:apply_mod, agent_id, mod_name, mod_type, config}, _from, state) do
    case apply_mod_impl(agent_id, mod_name, mod_type, config) do
      {:ok, mod} -> {:reply, {:ok, mod}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:tick_agent, agent_id}, _from, state) do
    case tick_agent_impl(agent_id) do
      {:ok, agent} -> {:reply, {:ok, agent}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_status, _from, state) do
    status = %{
      active_agents: MapSet.size(state.active_agents),
      tick_count: state.tick_count,
      last_tick: state.last_tick,
      uptime: DateTime.diff(DateTime.utc_now(), state.last_tick, :second)
    }

    {:reply, status, state}
  end

  def handle_info(:tick, state) do
    Logger.debug("PAC Manager tick #{state.tick_count + 1}")

    # Process tick for all active agents
    tick_results = process_global_tick(state.active_agents)

    # Update state
    new_state = %{state |
      tick_count: state.tick_count + 1,
      last_tick: DateTime.utc_now()
    }

    # Schedule next tick
    schedule_tick()

    # Broadcast tick event
    Phoenix.PubSub.broadcast(Thunderline.PubSub, "pac:ticks", {
      :tick_completed,
      new_state.tick_count,
      tick_results
    })

    {:noreply, new_state}
  end

  # Private Implementation

  defp create_agent_impl(name, zone_id, opts) do
    # Verify zone exists and has capacity
    case Zone.get_by_id(zone_id, load: [:agents]) do
      {:ok, zone} ->
        if length(zone.agents) < zone.max_agents do
          Agent.create(name, zone_id, opts)
        else
          {:error, :zone_at_capacity}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp apply_mod_impl(agent_id, mod_name, mod_type, config) do
    case Agent.get_by_id(agent_id) do
      {:ok, agent} ->
        Mod.create(mod_name, mod_type, agent_id, config: config)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp tick_agent_impl(agent_id) do
    case Agent.get_by_id(agent_id, load: [:mods]) do
      {:ok, agent} ->
        # Process agent tick
        with {:ok, updated_agent} <- Agent.tick(agent),
             {:ok, _} <- process_agent_mods(agent),
             {:ok, _} <- update_agent_memory(agent) do
          {:ok, updated_agent}
        else
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_global_tick(active_agent_ids) do
    # Convert MapSet to list for processing
    agent_ids = MapSet.to_list(active_agent_ids)

    # Process ticks in parallel for better performance
    agent_ids
    |> Task.async_stream(fn agent_id ->
      {agent_id, tick_agent_impl(agent_id)}
    end, max_concurrency: 10, timeout: 30_000)
    |> Enum.map(fn {:ok, result} -> result end)
    |> Enum.into(%{})
  end

  defp process_agent_mods(agent) do
    # Apply active mods and remove expired ones
    active_mods = Mod.list_by_agent(agent.id) |> Enum.filter(& &1.active)

    Enum.each(active_mods, fn mod ->
      if mod.duration && DateTime.utc_now() > DateTime.add(mod.applied_at, mod.duration, :second) do
        Mod.deactivate(mod)
      else
        Mod.apply_to_agent(mod)
      end
    end)

    {:ok, :processed}
  end

  defp update_agent_memory(agent) do
    # Update agent's memory context based on recent activities
    # This would integrate with the Memory system
    {:ok, :updated}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end
end
