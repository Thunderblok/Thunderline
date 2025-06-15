defmodule Thunderline.Zone.EventBroadway do
  @moduledoc """
  Broadway pipeline for processing zone events with concurrent, fault-tolerant broadcasting.

  This module handles real-time zone events inspired by Mozilla Reticulum's architecture:
  - Agent join/leave events
  - Resource changes
  - Environment updates
  - Inter-agent interactions

  Events are processed concurrently and broadcasted to Phoenix Channels for real-time updates.
  """

  use Broadway

  require Logger
  alias Broadway.Message
  alias Thunderline.PAC.Zone

  def start_link(opts) do
    config = build_config(opts)
    Broadway.start_link(__MODULE__, config)
  end

  @impl Broadway
  def handle_message(_, %Message{data: event_data} = message, _) do
    %{
      zone_id: zone_id,
      event_type: event_type,
      payload: payload
    } = event_data

    Logger.debug("Processing zone event: #{event_type} for zone #{zone_id}")

    case process_zone_event(zone_id, event_type, payload) do
      :ok ->
        # Update telemetry
        :telemetry.execute([:thunderline, :zone, :event, :success], %{count: 1}, %{
          zone_id: zone_id,
          event_type: event_type
        })

        message

      {:error, reason} ->
        Logger.error("Zone event failed for #{zone_id}: #{inspect(reason)}")

        # Update telemetry
        :telemetry.execute([:thunderline, :zone, :event, :failure], %{count: 1}, %{
          zone_id: zone_id,
          event_type: event_type,
          reason: reason
        })

        # Mark message as failed for retry
        Message.failed(message, reason)
    end
  end

  @impl Broadway
  def handle_failed(messages, _context) do
    Logger.warning("#{length(messages)} zone event messages failed, will retry")

    Enum.each(messages, fn %Message{data: %{zone_id: zone_id, event_type: event_type}} ->
      :telemetry.execute([:thunderline, :zone, :event, :retry], %{count: 1}, %{
        zone_id: zone_id,
        event_type: event_type
      })
    end)

    messages
  end

  @impl Broadway
  def handle_batch(_, messages, _, _) do
    # Process batch completion for analytics
    event_count = length(messages)

    Logger.debug("Completed batch of #{event_count} zone events")

    :telemetry.execute([:thunderline, :zone, :event, :batch_complete], %{count: event_count}, %{})

    messages
  end

  # Private Functions

  defp build_config(opts) do
    [
      name: __MODULE__,
      producer: [
        module: {Broadway.DummyProducer, []},
        transformer: {__MODULE__, :transform, []},
        concurrency: 1
      ],
      processors: [
        default: [
          concurrency: get_concurrency(),
          min_demand: 5,
          max_demand: 10
        ]
      ],
      batchers: [
        analytics: [
          concurrency: 1,
          batch_size: 20,
          batch_timeout: 2_000
        ]
      ],
      context: %{
        max_retries: Keyword.get(opts, :max_retries, 3)
      }
    ]
  end

  defp get_concurrency do
    # Base concurrency on system resources
    cores = System.schedulers_online()
    max(2, div(cores, 2))
  end

  defp process_zone_event(zone_id, event_type, payload) do
    # Broadcast to Phoenix Channel for real-time updates
    Zone.broadcast_to_channel(zone_id, event_type, payload)

    # Process specific event types
    case event_type do
      "agent_entered" ->
        handle_agent_entered(zone_id, payload)

      "agent_left" ->
        handle_agent_left(zone_id, payload)

      "resource_changed" ->
        handle_resource_changed(zone_id, payload)

      "environment_tick" ->
        handle_environment_tick(zone_id, payload)

      "agent_interaction" ->
        handle_agent_interaction(zone_id, payload)

      _ ->
        Logger.warning("Unknown zone event type: #{event_type}")
        :ok
    end
  end

  # Event Handlers
  # ==============

  defp handle_agent_entered(zone_id, %{agent_id: agent_id, session_count: session_count}) do
    Logger.info("Agent #{agent_id} entered zone #{zone_id}, active sessions: #{session_count}")

    # Update Phoenix Presence
    ThunderlineWeb.Presence.track(
      self(),
      "zone:#{zone_id}",
      agent_id,
      %{
        joined_at: DateTime.utc_now(),
        agent_id: agent_id
      }
    )

    :ok
  end

  defp handle_agent_left(zone_id, %{agent_id: agent_id, session_count: session_count}) do
    Logger.info("Agent #{agent_id} left zone #{zone_id}, active sessions: #{session_count}")

    # Update Phoenix Presence
    ThunderlineWeb.Presence.untrack(
      self(),
      "zone:#{zone_id}",
      agent_id
    )

    :ok
  end

  defp handle_resource_changed(zone_id, %{changes: changes, new_resources: new_resources}) do
    Logger.debug("Resources changed in zone #{zone_id}: #{inspect(changes)}")

    # Broadcast detailed resource update
    Zone.broadcast_to_channel(zone_id, "resource_update", %{
      changes: changes,
      resources: new_resources,
      timestamp: DateTime.utc_now()
    })

    :ok
  end

  defp handle_environment_tick(zone_id, %{properties: properties}) do
    Logger.debug("Environment tick for zone #{zone_id}")

    # Broadcast environment state to interested clients
    Zone.broadcast_to_channel(zone_id, "environment_update", %{
      properties: properties,
      timestamp: DateTime.utc_now()
    })

    :ok
  end

  defp handle_agent_interaction(zone_id, payload) do
    Logger.debug("Agent interaction in zone #{zone_id}: #{inspect(payload)}")

    # Broadcast interaction event for real-time coordination
    Zone.broadcast_to_channel(zone_id, "agent_interaction", payload)

    :ok
  end

  # Transform function for producer messages
  def transform(event, _opts) do
    %Message{
      data: event,
      acknowledger: {__MODULE__, :ack_id, :ack_data}
    }
  end

  # Simple acknowledger
  def ack(:ack_id, successful, failed) do
    Logger.debug(
      "Zone events acknowledged: #{length(successful)} successful, #{length(failed)} failed"
    )

    :ok
  end
end
