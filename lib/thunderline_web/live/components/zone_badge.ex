defmodule ThunderlineWeb.Components.ZoneBadge do
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="zone-badge">
      <span class="event-icon"><%= display_event_icon(@zone_event) %></span>
      <span class="entropy-value">E: <%= @entropy || "N/A" %></span>
    </div>
    """
  end

  defp display_event_icon(nil), do: "❓" # Default for no event
  defp display_event_icon(zone_event) do
    # Assuming zone_event is a map with a :type or similar key
    # This can be expanded with more event types and icons
    case Map.get(zone_event, :type, :unknown) do
      :alert -> "⚠️"
      :anomaly -> "🌀"
      :stable -> "✅"
      :energy_spike -> "⚡"
      :comms_disruption -> "📡"
      _ -> "❓" # Default for unknown event type
    end
  end
end
