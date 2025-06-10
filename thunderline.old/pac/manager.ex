defmodule Thunderline.PAC.Manager do
  @moduledoc """
  PAC Manager - Handles PAC lifecycle, state management, and orchestration.

  Responsibilities:
  - PAC creation, activation, and deactivation
  - Zone assignment and movement
  - Mod application and removal
  - State transitions and validation
  - Integration with Jido agents for AI reasoning

  The Manager acts as the central coordinator for all PAC operations,
  ensuring consistency and proper state management across the substrate.
  """

  use GenServer
  require Logger

  alias Thunderline.{PAC, Repo}
  alias Thunderline.PAC.{Mod, Zone}
  alias Thunderline.Tick.TickWorker

  @behaviour Thunderline.PAC.Behaviour

  defstruct [:pacs, :zones, :tick_registry]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def create_pac(attrs) do
    GenServer.call(__MODULE__, {:create_pac, attrs})
  end

  def activate_pac(pac_id) do
    GenServer.call(__MODULE__, {:activate_pac, pac_id})
  end

  def deactivate_pac(pac_id) do
    GenServer.call(__MODULE__, {:deactivate_pac, pac_id})
  end

  def move_pac_to_zone(pac_id, zone_id) do
    GenServer.call(__MODULE__, {:move_pac_to_zone, pac_id, zone_id})
  end

  def apply_mod_to_pac(pac_id, mod_id) do
    GenServer.call(__MODULE__, {:apply_mod, pac_id, mod_id})
  end

  def remove_mod_from_pac(pac_id, mod_id) do
    GenServer.call(__MODULE__, {:remove_mod, pac_id, mod_id})
  end

  def get_pac(pac_id) do
    GenServer.call(__MODULE__, {:get_pac, pac_id})
  end

  def list_active_pacs do
    GenServer.call(__MODULE__, :list_active_pacs)
  end

  def get_zone_pacs(zone_id) do
    GenServer.call(__MODULE__, {:get_zone_pacs, zone_id})
  end

  # Server Implementation

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      pacs: %{},
      zones: %{},
      tick_registry: %{}
    }

    # Load existing active PACs and zones
    {:ok, state, {:continue, :load_existing_data}}
  end

  @impl true
  def handle_continue(:load_existing_data, state) do
    Logger.info("Loading existing PACs and zones...")

    # Load active PACs
    active_pacs =
      PAC
      |> Ash.Query.filter(not is_nil(last_tick_at))
      |> Ash.read!(domain: Thunderline.Domain)
      |> Enum.map(&{&1.id, &1})
      |> Map.new()

    # Load active zones
    active_zones =
      Zone
      |> Ash.Query.filter(active == true)
      |> Ash.read!(domain: Thunderline.Domain)
      |> Enum.map(&{&1.id, &1})
      |> Map.new()

    Logger.info("Loaded #{map_size(active_pacs)} active PACs and #{map_size(active_zones)} zones")

    # Schedule tick jobs for active PACs
    tick_registry = schedule_ticks_for_pacs(active_pacs)

    new_state = %{state |
      pacs: active_pacs,
      zones: active_zones,
      tick_registry: tick_registry
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:create_pac, attrs}, _from, state) do
    case create_pac_with_defaults(attrs) do
      {:ok, pac} ->
        new_pacs = Map.put(state.pacs, pac.id, pac)
        new_state = %{state | pacs: new_pacs}

        Logger.info("Created PAC: #{pac.name} (#{pac.id})")
        {:reply, {:ok, pac}, new_state}

      {:error, error} ->
        Logger.error("Failed to create PAC: #{inspect(error)}")
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call({:activate_pac, pac_id}, _from, state) do
    case Map.get(state.pacs, pac_id) do
      nil ->
        # Try to load from database
        case load_pac(pac_id) do
          {:ok, pac} ->
            activated_pac = activate_pac_ticks(pac)
            job_ref = schedule_tick_job(activated_pac)

            new_pacs = Map.put(state.pacs, pac_id, activated_pac)
            new_tick_registry = Map.put(state.tick_registry, pac_id, job_ref)
            new_state = %{state | pacs: new_pacs, tick_registry: new_tick_registry}

            Logger.info("Activated PAC: #{activated_pac.name} (#{pac_id})")
            {:reply, {:ok, activated_pac}, new_state}

          error ->
            {:reply, error, state}
        end

      pac ->
        if pac.last_tick_at do
          {:reply, {:ok, pac}, state}
        else
          activated_pac = activate_pac_ticks(pac)
          job_ref = schedule_tick_job(activated_pac)

          new_pacs = Map.put(state.pacs, pac_id, activated_pac)
          new_tick_registry = Map.put(state.tick_registry, pac_id, job_ref)
          new_state = %{state | pacs: new_pacs, tick_registry: new_tick_registry}

          {:reply, {:ok, activated_pac}, new_state}
        end
    end
  end

  @impl true
  def handle_call({:deactivate_pac, pac_id}, _from, state) do
    case Map.get(state.tick_registry, pac_id) do
      nil ->
        {:reply, {:ok, :already_inactive}, state}

      job_ref ->
        # Cancel the scheduled tick job
        Oban.cancel_job(job_ref)

        new_tick_registry = Map.delete(state.tick_registry, pac_id)
        new_state = %{state | tick_registry: new_tick_registry}

        Logger.info("Deactivated PAC ticks: #{pac_id}")
        {:reply, {:ok, :deactivated}, new_state}
    end
  end

  @impl true
  def handle_call({:move_pac_to_zone, pac_id, zone_id}, _from, state) do
    with {:ok, pac} <- get_pac_from_state(state, pac_id),
         {:ok, zone} <- get_zone_from_state(state, zone_id),
         {:ok, updated_pac} <- move_pac_to_zone_impl(pac, zone) do

      new_pacs = Map.put(state.pacs, pac_id, updated_pac)
      new_state = %{state | pacs: new_pacs}

      Logger.info("Moved PAC #{pac.name} to zone #{zone.name}")
      {:reply, {:ok, updated_pac}, new_state}
    else
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:apply_mod, pac_id, mod_id}, _from, state) do
    with {:ok, pac} <- get_pac_from_state(state, pac_id),
         {:ok, updated_pac} <- apply_mod_to_pac_impl(pac, mod_id) do

      new_pacs = Map.put(state.pacs, pac_id, updated_pac)
      new_state = %{state | pacs: new_pacs}

      Logger.info("Applied mod #{mod_id} to PAC #{pac.name}")
      {:reply, {:ok, updated_pac}, new_state}
    else
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_pac, pac_id}, _from, state) do
    case get_pac_from_state(state, pac_id) do
      {:ok, pac} -> {:reply, {:ok, pac}, state}
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:list_active_pacs, _from, state) do
    active_pacs = Map.values(state.pacs)
    {:reply, {:ok, active_pacs}, state}
  end

  @impl true
  def handle_call({:get_zone_pacs, zone_id}, _from, state) do
    zone_pacs =
      state.pacs
      |> Map.values()
      |> Enum.filter(&(&1.zone_id == zone_id))

    {:reply, {:ok, zone_pacs}, state}
  end

  # Private implementation functions

  defp create_pac_with_defaults(attrs) do
    PAC
    |> Ash.Changeset.for_create(:create_with_defaults, attrs)
    |> Ash.create(domain: Thunderline.Domain)
  end

  defp load_pac(pac_id) do
    case Ash.get(PAC, pac_id, domain: Thunderline.Domain) do
      {:ok, pac} -> {:ok, pac}
      {:error, _} -> {:error, :pac_not_found}
    end
  end

  defp activate_pac_ticks(pac) do
    pac
    |> Ash.Changeset.for_update(:apply_tick, %{last_tick_at: DateTime.utc_now()})
    |> Ash.update!(domain: Thunderline.Domain)
  end

  defp schedule_tick_job(pac) do
    # Schedule immediate first tick, then regular intervals
    %{pac_id: pac.id}
    |> TickWorker.new(schedule_in: 5) # 5 seconds for first tick
    |> Oban.insert!()
  end

  defp schedule_ticks_for_pacs(pacs) do
    pacs
    |> Enum.map(fn {pac_id, pac} ->
      job_ref = schedule_tick_job(pac)
      {pac_id, job_ref}
    end)
    |> Map.new()
  end

  defp get_pac_from_state(state, pac_id) do
    case Map.get(state.pacs, pac_id) do
      nil ->
        case load_pac(pac_id) do
          {:ok, pac} -> {:ok, pac}
          error -> error
        end
      pac -> {:ok, pac}
    end
  end

  defp get_zone_from_state(state, zone_id) do
    case Map.get(state.zones, zone_id) do
      nil ->
        case Ash.get(Zone, zone_id, domain: Thunderline.Domain) do
          {:ok, zone} -> {:ok, zone}
          {:error, _} -> {:error, :zone_not_found}
        end
      zone -> {:ok, zone}
    end
  end

  defp move_pac_to_zone_impl(pac, zone) do
    # Check zone capacity
    max_pacs = get_in(zone.rules, ["max_pacs"]) || 10

    if zone.current_pac_count >= max_pacs do
      {:error, :zone_at_capacity}
    else
      # Update PAC's zone
      updated_pac =
        pac
        |> Ash.Changeset.for_update(:update, %{zone_id: zone.id})
        |> Ash.update!(domain: Thunderline.Domain)

      # Update zone's PAC count
      zone
      |> Ash.Changeset.for_update(:add_pac, %{})
      |> Ash.update!(domain: Thunderline.Domain)

      # If PAC had previous zone, decrement that count
      if pac.zone_id && pac.zone_id != zone.id do
        case Ash.get(Zone, pac.zone_id, domain: Thunderline.Domain) do
          {:ok, old_zone} ->
            old_zone
            |> Ash.Changeset.for_update(:remove_pac, %{})
            |> Ash.update!(domain: Thunderline.Domain)
          _ -> :ok
        end
      end

      {:ok, updated_pac}
    end
  end

  defp apply_mod_to_pac_impl(pac, mod_id) do
    case Ash.get(Mod, mod_id, domain: Thunderline.Domain) do
      {:ok, mod} ->
        # TODO: Implement mod compatibility checking
        # TODO: Apply stat modifiers and effects

        # For now, just add the relationship
        case Ash.Changeset.manage_relationship(
          Ash.Changeset.for_update(pac, :update, %{}),
          :mods,
          [mod],
          type: :append_and_remove
        ) |> Ash.update(domain: Thunderline.Domain) do
          {:ok, updated_pac} -> {:ok, updated_pac}
          {:error, error} -> {:error, error}
        end

      {:error, _} ->
        {:error, :mod_not_found}
    end
  end
end
