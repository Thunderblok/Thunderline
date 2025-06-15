defmodule ThunderlineWeb.Components.TickHistoryItem do
  use Phoenix.LiveComponent
  alias Timex # Added alias for Timex

  @impl true
  def render(assigns) do
    ~H"""
    <li id={@id} class="border-b border-slate-700 pb-3 mb-3 bg-slate-800/30 p-2 rounded-sm shadow">
      <div class="flex justify-between items-center mb-1">
        <span class="font-semibold text-cyan-400">Tick #<%= @tick_log.tick_number || "N/A" %></span>
        <span :if={@tick_log.inserted_at} class="text-xs text-gray-500" title={to_string(@tick_log.inserted_at)}>
          <%= Timex.format!(@tick_log.inserted_at, "{relative}", :relative) %>
        </span>
      </div>
      <%# Assuming decision_summary contains the main information. Adapt if structure is different. %>
      <p class="text-gray-300 leading-relaxed"><%= Map.get(@tick_log.data, "decision_summary", "No decision summary available.") %></p>

      <%# Example: Displaying other potential fields from tick_log.data %>
      <%# <p :if={Map.get(@tick_log.data, "action_taken")} class="text-xs text-sky-400">Action: <%= Map.get(@tick_log.data, "action_taken") %></p> %>
      <%# <p :if={Map.get(@tick_log.data, "result_status")} class="text-xs text-yellow-400">Result: <%= Map.get(@tick_log.data, "result_status") %></p> %>
    </li>
    """
  end
end
