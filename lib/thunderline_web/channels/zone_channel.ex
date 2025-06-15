defmodule ThunderlineWeb.ZoneChannel do  @moduledoc """
  Phoenix Channel for real-time zone coordination and event broadcasting.

  Inspired by Mozilla Reticulum's channel-based architecture for handling:
  - Agent presence in zones
  - Real-time zone events
  - Resource updates
  - Environmental changes
  - Inter-agent interactions

  Channels follow the pattern "zone:ZONE_ID" for zone-specific subscriptions.
  """

  use ThunderlineWeb, :channel

  require Logger
  alias Thunderline.PAC.{Zone, Agent}
  alias ThunderlineWeb.Presence

  # Channel Join/Leave
  # ==================

  @doc """
  Join a zone channel. Validates permissions and tracks presence.
  """
  def join("zone:" <> zone_id, params, socket) do
    Logger.info("Attempting to join zone:#{zone_id}")

    case UUID.cast(zone_id) do
      {:ok, zone_uuid} ->
        handle_zone_join(zone_uuid, params, socket)

      :error ->
        Logger.warning("Invalid zone ID format: #{zone_id}")
        {:error, %{reason: "invalid_zone_id"}}
    end
  end

  def join(_, _, _socket) do
    {:error, %{reason: "invalid_topic"}}
  end

  @doc """
  Handle zone join with permission validation.
  """
  defp handle_zone_join(zone_id, params, socket) do
    with {:ok, zone} <- Zone.get_by_id(zone_id),
         {:ok, agent_id} <- get_agent_id(params),
         {:ok, agent} <- Agent.get_by_id(agent_id),
         :ok <- validate_zone_access(zone, agent, params) do
      # Update socket with zone and agent info
      socket =
        socket
        |> assign(:zone_id, zone_id)
        |> assign(:agent_id, agent_id)
        |> assign(:zone, zone)
        |> assign(:agent, agent)

      # Track presence
      track_presence(socket)

      # Notify zone of agent entry
      Zone.agent_entered(zone, agent_id)

      # Send initial zone state
      push(socket, "zone_state", %{
        zone: serialize_zone(zone),
        agents: get_zone_agents(zone),
        resources: Map.get(zone.properties, "resources", %{}),
        timestamp: DateTime.utc_now()
      })

      Logger.info("Agent #{agent_id} joined zone #{zone_id}")
      {:ok, socket}
    else
      {:error, :not_found} ->
        Logger.warning("Zone not found: #{zone_id}")
        {:error, %{reason: "zone_not_found"}}

      {:error, :access_denied} ->
        Logger.warning("Access denied to zone #{zone_id}")
        {:error, %{reason: "access_denied"}}

      {:error, reason} ->
        Logger.error("Failed to join zone #{zone_id}: #{inspect(reason)}")
        {:error, %{reason: "join_failed"}}
    end
  end

  # Message Handlers
  # ================

  @doc """
  Handle agent movement within the zone.
  """
  def handle_in("agent_move", %{"position" => position}, socket) do
    zone_id = socket.assigns.zone_id
    agent_id = socket.assigns.agent_id

    # Broadcast movement to other agents in zone
    broadcast_from(socket, "agent_moved", %{
      agent_id: agent_id,
      position: position,
      timestamp: DateTime.utc_now()
    })

    # Log movement for analytics
    :telemetry.execute([:thunderline, :zone, :agent_movement], %{count: 1}, %{
      zone_id: zone_id,
      agent_id: agent_id
    })

    {:reply, :ok, socket}
  end

  @doc """
  Handle agent interactions within the zone.
  """
  def handle_in(
        "agent_interact",
        %{"target_agent_id" => target_id, "interaction_type" => type} = params,
        socket
      ) do
    zone_id = socket.assigns.zone_id
    agent_id = socket.assigns.agent_id

    interaction_data = %{
      source_agent_id: agent_id,
      target_agent_id: target_id,
      interaction_type: type,
      data: Map.get(params, "data", %{}),
      timestamp: DateTime.utc_now()
    }

    # Broadcast via Zone's Broadway pipeline for processing
    Zone.broadcast_zone_event(zone_id, "agent_interaction", interaction_data)

    {:reply, :ok, socket}
  end

  @doc """
  Handle resource consumption requests.
  """
  def handle_in(
        "consume_resource",
        %{"resource_type" => resource_type, "amount" => amount},
        socket
      ) do
    zone = socket.assigns.zone
    agent_id = socket.assigns.agent_id

    # Validate resource availability
    resources = Map.get(zone.properties, "resources", %{})
    current_amount = Map.get(resources, resource_type, 0)

    if current_amount >= amount do
      # Consume resources via Zone action
      resource_changes = %{resource_type => -amount}

      case Zone.consume_resources(zone, resource_changes) do
        {:ok, _updated_zone} ->
          Logger.info("Agent #{agent_id} consumed #{amount} #{resource_type}")
          {:reply, {:ok, %{consumed: amount}}, socket}

        {:error, reason} ->
          Logger.error("Resource consumption failed: #{inspect(reason)}")
          {:reply, {:error, %{reason: "consumption_failed"}}, socket}
      end
    else
      Logger.warning(
        "Insufficient resources: #{resource_type} (requested: #{amount}, available: #{current_amount})"
      )

      {:reply, {:error, %{reason: "insufficient_resources"}}, socket}
    end
  end

  @doc """
  Handle zone state requests.
  """
  def handle_in("get_zone_state", _params, socket) do
    zone = socket.assigns.zone

    state = %{
      zone: serialize_zone(zone),
      agents: get_zone_agents(zone),
      resources: Map.get(zone.properties, "resources", %{}),
      timestamp: DateTime.utc_now()
    }

    {:reply, {:ok, state}, socket}
  end

  # Channel Events
  # ==============

  @doc """
  Handle zone events broadcasted via Broadway.
  """
  def handle_info({event_type, payload}, socket) do
    push(socket, event_type, payload)
    {:noreply, socket}
  end

  @doc """
  Handle presence updates.
  """
  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    push(socket, "presence_diff", diff)
    {:noreply, socket}
  end

  # Channel Termination
  # ===================

  @doc """
  Handle channel termination and cleanup.
  """
  def terminate(reason, socket) do
    Logger.info("Zone channel terminating: #{inspect(reason)}")

    if Map.has_key?(socket.assigns, :zone_id) and Map.has_key?(socket.assigns, :agent_id) do
      zone_id = socket.assigns.zone_id
      agent_id = socket.assigns.agent_id

      # Notify zone of agent departure
      case Zone.get_by_id(zone_id) do
        {:ok, zone} ->
          Zone.agent_left(zone, agent_id)
          Logger.info("Agent #{agent_id} left zone #{zone_id}")

        {:error, _} ->
          Logger.warning("Could not find zone #{zone_id} during cleanup")
      end
    end

    :ok
  end

  # Private Helper Functions
  # ========================

  defp get_agent_id(%{"agent_id" => agent_id}) when is_binary(agent_id) do
    case UUID.cast(agent_id) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, :invalid_agent_id}
    end
  end

  defp get_agent_id(_), do: {:error, :missing_agent_id}

  defp validate_zone_access(zone, agent, _params) do
    # Check if zone allows agent spawning
    if Zone.can_spawn_agent?(zone) do
      # Additional validation can be added here
      # (e.g., agent permissions, zone capacity, etc.)
      :ok
    else
      {:error, :access_denied}
    end
  end

  defp track_presence(socket) do
    zone_id = socket.assigns.zone_id
    agent_id = socket.assigns.agent_id

    Presence.track(socket, "zone:#{zone_id}", agent_id, %{
      agent_id: agent_id,
      joined_at: DateTime.utc_now(),
      online_at: inspect(System.system_time(:second))
    })
  end

  defp serialize_zone(zone) do
    %{
      id: zone.id,
      name: zone.name,
      description: zone.description,
      size: zone.size,
      max_agents: zone.max_agents,
      active_session_count: zone.active_session_count,
      properties: zone.properties,
      rules: zone.rules
    }
  end

  defp get_zone_agents(zone) do
    # Get current presence for real-time agent list
    zone_topic = "zone:#{zone.id}"

    Presence.list(zone_topic)
    |> Enum.map(fn {agent_id, %{metas: [meta | _]}} ->
      %{
        agent_id: agent_id,
        joined_at: meta.joined_at,
        online_at: meta.online_at
      }
    end)
  end
end
