defmodule Thunderline.World.ZoneOrchestrator do
  @moduledoc """
  Zone Orchestrator - Global ticker for zone tock updates.

  Manages the "tock" cycle that complements agent "tick" cycles:
  - Tick: Per-agent action cycle (Assess, Decide, Act, Memorize)
  - Tock: Per-zone diffusion cycle (Environment mutates, ripples, feedback)

  The ZoneOrchestrator periodically updates all zones with:
  - New events and environmental changes
  - Entropy and temperature diffusion
  - Cross-zone ripple effects
  - PubSub broadcasts for real-time updates
  """

  use GenServer
  require Logger

  alias Thunderline.World.{Zone, ZoneEvent}
  alias Thunderline.Domain

  # Zone tock interval - every 30 seconds by default
  @tick_interval_ms Application.compile_env(:thunderline, [:zone_orchestrator, :tick_interval], 30_000)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("ZoneOrchestrator starting with #{@tick_interval_ms}ms tock interval")
    schedule_tock()

    {:ok, %{
      tock_count: 0,
      last_tock: DateTime.utc_now(),
      zones_updated: 0,
      events_generated: 0
    }}
  end

  # Client API

  @doc """
  Manually trigger a zone tock cycle (useful for testing).
  """
  def trigger_tock do
    GenServer.cast(__MODULE__, :manual_tock)
  end

  @doc """
  Get current orchestrator statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Update tock interval (in milliseconds).
  """
  def set_interval(new_interval_ms) when is_integer(new_interval_ms) and new_interval_ms > 0 do
    GenServer.cast(__MODULE__, {:set_interval, new_interval_ms})
  end

  # Server callbacks

  def handle_info(:tick_zones, state) do
    Logger.debug("ZoneOrchestrator executing global tock cycle #{state.tock_count + 1}")

    {zones_updated, events_generated} = update_all_zones()
    schedule_tock()

    new_state = %{
      state |
      tock_count: state.tock_count + 1,
      last_tock: DateTime.utc_now(),
      zones_updated: zones_updated,
      events_generated: events_generated
    }

    Logger.debug("Tock cycle complete: #{zones_updated} zones updated, #{events_generated} events generated")
    {:noreply, new_state}
  end

  def handle_cast(:manual_tock, state) do
    Logger.info("Manual tock cycle triggered")
    {zones_updated, events_generated} = update_all_zones()

    new_state = %{
      state |
      zones_updated: zones_updated,
      events_generated: events_generated
    }

    {:noreply, new_state}
  end

  def handle_cast({:set_interval, new_interval}, state) do
    Logger.info("ZoneOrchestrator interval updated to #{new_interval}ms")
    {:noreply, Map.put(state, :interval, new_interval)}
  end

  def handle_call(:get_stats, _from, state) do
    stats = %{
      tock_count: state.tock_count,
      last_tock: state.last_tock,
      zones_updated: state.zones_updated,
      events_generated: state.events_generated,
      interval_ms: @tick_interval_ms,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.last_tock)
    }

    {:reply, stats, state}
  end

  # Private functions

  defp schedule_tock do
    Process.send_after(self(), :tick_zones, @tick_interval_ms)
  end

  defp update_all_zones do
    # Get all zones
    zones = Domain.read!(Zone)

    zones_updated = 0
    events_generated = 0

    {updated_count, event_count} = zones
    |> Enum.reduce({0, 0}, fn zone, {zone_acc, event_acc} ->
      case tick_zone(zone) do
        {:ok, updated_zone, had_event?} ->
          # Broadcast zone update
          broadcast_zone_update(updated_zone)

          # Apply diffusion effects to neighboring zones
          apply_diffusion_effects(updated_zone, zones)

          {zone_acc + 1, event_acc + (if had_event?, do: 1, else: 0)}

        {:error, reason} ->
          Logger.warning("Failed to update zone #{zone.id}: #{inspect(reason)}")
          {zone_acc, event_acc}
      end
    end)

    {updated_count, event_count}
  end

  defp tick_zone(zone) do
    # Generate new event
    new_event = ZoneEvent.generate(zone)
    had_event? = Map.get(new_event, "type") != "quiet_zone"

    # Apply event effects to zone properties
    {new_entropy, new_temp} = ZoneEvent.apply_event_effects(zone, new_event)

    # Update zone
    case Domain.update(zone, %{
      event: new_event,
      entropy: new_entropy,
      temperature: new_temp,
      last_updated_at: DateTime.utc_now()
    }) do
      {:ok, updated_zone} ->
        if had_event? do
          Logger.debug("Zone #{inspect(zone.coords)} generated event: #{Map.get(new_event, "type")}")
        end
        {:ok, updated_zone, had_event?}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp broadcast_zone_update(zone) do
    # Broadcast to zone-specific topic
    Phoenix.PubSub.broadcast(
      Thunderline.PubSub,
      "zone:#{zone.id}",
      {:zone_updated, %{
        zone_id: zone.id,
        coords: zone.coords,
        event: zone.event,
        entropy: zone.entropy,
        temperature: zone.temperature,
        last_updated_at: zone.last_updated_at
      }}
    )

    # Broadcast to global zones topic
    Phoenix.PubSub.broadcast(
      Thunderline.PubSub,
      "zones:all",
      {:zone_tock, %{
        zone_id: zone.id,
        coords: zone.coords,
        event: zone.event
      }}
    )
  end

  defp apply_diffusion_effects(source_zone, all_zones) do
    # Get zones adjacent to the source zone (within distance of 1)
    source_coords = source_zone.coords
    adjacent_zones = find_adjacent_zones(source_zone, all_zones)

    # Apply diffusion based on source zone's entropy and temperature
    source_entropy = Decimal.to_float(source_zone.entropy || Decimal.new("0.0"))
    source_temp = Decimal.to_float(source_zone.temperature || Decimal.new("0.0"))

    # Only apply significant diffusion if values are above threshold
    if source_entropy > 0.5 or abs(source_temp) > 0.3 do
      Enum.each(adjacent_zones, fn adjacent_zone ->
        apply_diffusion_to_zone(adjacent_zone, source_entropy, source_temp)
      end)
    end
  end

  defp find_adjacent_zones(source_zone, all_zones) do
    source_coords = source_zone.coords

    Enum.filter(all_zones, fn zone ->
      zone.id != source_zone.id and
      coords_adjacent?(source_coords, zone.coords)
    end)
  end

  defp coords_adjacent?(coords1, coords2) do
    # Use Graphmath to calculate 3D distance
    try do
      x1 = Map.get(coords1, "x", 0)
      y1 = Map.get(coords1, "y", 0)
      z1 = Map.get(coords1, "z", 0)

      x2 = Map.get(coords2, "x", 0)
      y2 = Map.get(coords2, "y", 0)
      z2 = Map.get(coords2, "z", 0)

      vec1 = Graphmath.Vec3.create(x1, y1, z1)
      vec2 = Graphmath.Vec3.create(x2, y2, z2)

      distance = Graphmath.Vec3.length(Graphmath.Vec3.subtract(vec2, vec1))

      # Adjacent if distance <= sqrt(3) (diagonal neighbors in 3D grid)
      distance <= 1.8
    rescue
      _ -> false
    end
  end

  defp apply_diffusion_to_zone(zone, source_entropy, source_temp) do
    # Apply 20% of source zone's entropy and temperature
    diffusion_factor = 0.2

    current_entropy = Decimal.to_float(zone.entropy || Decimal.new("0.0"))
    current_temp = Decimal.to_float(zone.temperature || Decimal.new("0.0"))

    # Gradual diffusion
    entropy_change = (source_entropy - current_entropy) * diffusion_factor
    temp_change = (source_temp - current_temp) * diffusion_factor

    new_entropy = Decimal.from_float(current_entropy + entropy_change)
    new_temp = Decimal.from_float(current_temp + temp_change)

    # Clamp values
    clamped_entropy = Decimal.max(Decimal.new("0.0"), Decimal.min(new_entropy, Decimal.new("1.0")))
    clamped_temp = Decimal.max(Decimal.new("-1.0"), Decimal.min(new_temp, Decimal.new("1.0")))

    # Update zone if changes are significant
    if abs(entropy_change) > 0.01 or abs(temp_change) > 0.01 do
      case Domain.update(zone, %{
        entropy: clamped_entropy,
        temperature: clamped_temp
      }) do
        {:ok, _updated_zone} ->
          :ok
        {:error, reason} ->
          Logger.debug("Failed to apply diffusion to zone #{zone.id}: #{inspect(reason)}")
      end
    end
  end
end
