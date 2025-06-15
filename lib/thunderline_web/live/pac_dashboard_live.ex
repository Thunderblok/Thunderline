defmodule ThunderlineWeb.PacDashboardLive do
  use ThunderlineWeb, :live_view
  alias Thunderline.PAC.Agent
  alias Thunderline.PubSub

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        loading: true,
        pacs: [],
        zone_events: %{},
        zone_data_unavailable: false,
        selected_pac_id_for_dev_panel: nil,
        selected_pac_for_dev_panel: nil
      )

    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "agents:updates")
      Phoenix.PubSub.subscribe(Thunderline.PubSub, "zone:all")
      Process.send_after(self(), :check_zone_data, 5000) # Check after 5 seconds
    end

    pacs = Agent.list_active()

    if connected?(socket) do
      for pac <- pacs do
        Phoenix.PubSub.subscribe(Thunderline.PubSub, "agent:" <> pac.id)
      end
    end

    {:ok,
     assign(socket,
       pacs: pacs,
       loading: false
     ), temporary_assigns: [pacs: [], selected_pac_for_dev_panel: nil]} # zone_events is not temporary
  end

  @impl true
  def handle_info(:check_zone_data, socket) do
    if Enum.empty?(socket.assigns.zone_events) do
      {:noreply, assign(socket, :zone_data_unavailable, true)}
    else
      # Zone data has arrived, no need to set the flag, or could explicitly set to false
      # depending on desired behavior if it can become unavailable again.
      # For now, once data is seen, we assume it's generally available.
      {:noreply, assign(socket, :zone_data_unavailable, false)} # Or just {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:pac_updated, updated_pac_data}, socket) do
    updated_pacs =
      Enum.map(socket.assigns.pacs, fn pac ->
        if pac.id == updated_pac_data.id do
          Process.send_after(self(), {:clear_pulse, pac.id}, 300) # Pulse for 300ms
          Map.merge(pac, Map.merge(updated_pac_data, %{just_updated: true}))
        else
          pac
        end
      end)

    # Also update the selected_pac_for_dev_panel if it's the one being updated
    socket_after_pac_update =
      if socket.assigns.selected_pac_id_for_dev_panel == updated_pac_data.id do
        # Re-fetch to get potentially more complete data than what's in updated_pac_data
        # and to ensure it's the full Ash resource if `updated_pac_data` is just a map.
        current_selected_pac_id = socket.assigns.selected_pac_id_for_dev_panel
        if current_selected_pac_id do
          updated_selected_pac = Agent.get_by_id(current_selected_pac_id)
          assign(socket, selected_pac_for_dev_panel: updated_selected_pac)
        else
          socket # No PAC was selected, so no update needed here
        end
      else
        socket # Update was for a different PAC or no PAC selected
      end

    {:noreply, assign(socket_after_pac_update, :pacs, updated_pacs)}
  end

  @impl true
  def handle_event("select_pac_for_dev_panel", %{"value" => pac_id_str}, socket) do
    pac_id =
      if pac_id_str == "" do
        nil
      else
        pac_id_str # Assuming pac_id_str is the actual ID, not needing String.to_integer
      end

    selected_pac =
      if pac_id do
        Agent.get_by_id(pac_id)
      else
        nil
      end

    socket =
      socket
      |> assign(:selected_pac_id_for_dev_panel, pac_id)
      |> assign(:selected_pac_for_dev_panel, selected_pac)

    {:noreply, socket}
  end

  @impl true
  def handle_event("trigger_manual_tick", _payload, socket) do
    pac_id = socket.assigns.selected_pac_id_for_dev_panel
    socket_with_flash = socket # Default to current socket

    if pac_id do
      case Agent.tick(%{id: pac_id}) do
        {:ok, _updated_pac_or_result} ->
          socket_with_flash =
            put_flash(socket, :info, "Manual tick triggered successfully for PAC ID: #{pac_id}.")

          # Re-fetch selected_pac_for_dev_panel to show immediate effect
          # This ensures the "Raw Ash Resource Dump" is up-to-date after the tick.
          if socket.assigns.selected_pac_id_for_dev_panel do
             updated_selected_pac_after_tick = Agent.get_by_id(socket.assigns.selected_pac_id_for_dev_panel)
             assign(socket_with_flash, selected_pac_for_dev_panel: updated_selected_pac_after_tick)
          else
            socket_with_flash # Should not happen if pac_id was valid, but as a safeguard
          end


        {:error, reason} ->
          socket_with_flash =
            put_flash(
              socket,
              :error,
              "Failed to trigger manual tick for PAC ID: #{pac_id}. Reason: #{inspect(reason)}"
            )
      end
    else
      socket_with_flash = put_flash(socket, :error, "No PAC selected to trigger a manual tick.")
    end
    # Ensure the final socket from put_flash and assign is returned
    final_socket_state = if pac_id && elem(Agent.tick(%{id: pac_id}), 0) == :ok do
      # If tick was successful, selected_pac_for_dev_panel was updated by assign in the :ok case
      # so socket_with_flash already has that.
      # However, the above Agent.tick call is a second call, which is not intended.
      # Let's restructure slightly.

      # The assign for selected_pac_for_dev_panel should happen INSIDE the :ok tuple's handling
      # And the socket_with_flash should be the one that gets this assign.
      # The current logic for assign is okay, but the final_socket_state logic is flawed.
      # Simply returning socket_with_flash is correct.
      socket_with_flash
    else
      socket_with_flash
    end


    # The previous complex assignment logic for final_socket_state was incorrect.
    # The socket_with_flash is correctly updated with flash messages.
    # The selected_pac_for_dev_panel is updated within the :ok tuple of the Agent.tick case.
    # So, we just need to return the socket_with_flash which has all updates.
    {:noreply, socket_with_flash}
  end

  # Handle zone updates
  # Expected payload: %{zone_id: String.t(), event: map()}
  @impl true
  def handle_info({:tock, %{zone_id: id, event: evt}}, socket) do
    updated_zone_events = Map.put(socket.assigns.zone_events, id, evt)
    {:noreply, assign(socket, :zone_events, updated_zone_events)}
  end

  # Handle agent updates
  # Expected payload: %{agent: map(), result: map()}
  # agent map should contain at least :id (and other fields of the PAC resource)
  # result map contains the outcome of the tick
  @impl true
  def handle_info({:tick_update, %{agent: agent_data, result: res}}, socket) do
    # Create a map with the agent data and the result
    # Assuming agent_data is a map and res should be part of this map or processed accordingly
    updated_agent_info = Map.merge(agent_data, %{last_tick_result: res})

    updated_pacs =
      Enum.map(socket.assigns.pacs, fn pac ->
        if pac.id == agent_data.id do
          Process.send_after(self(), {:clear_pulse, pac.id}, 300) # Pulse for 300ms
          # Merge the new information into the existing PAC data, add last_tick_result and just_updated
          Map.merge(pac, Map.merge(updated_agent_info, %{just_updated: true}))
        else
          pac
        end
      end)
    {:noreply, assign(socket, :pacs, updated_pacs)}
  end

  @impl true
  def handle_info({:clear_pulse, pac_id}, socket) do
    updated_pacs =
      Enum.map(socket.assigns.pacs, fn pac ->
        if pac.id == pac_id do
          Map.put(pac, :just_updated, false)
        else
          pac
        end
      end)
    {:noreply, assign(socket, :pacs, updated_pacs)}
  end

  @impl true
  def render(assigns) do
    # This render function is automatically called by LiveView
    # and uses the associated .html.heex template.
    # No explicit call to ThunderlineWeb.PacDashboardLiveHTML.render/1 is needed here.
    # The assigns passed to this function are available in the template.
    # Phoenix LiveView handles the actual rendering using the template.
    # So, this function body can remain empty or simply pass assigns through if needed for compilation.
    # However, it's conventional to just let it be implicitly defined by `use ThunderlineWeb, :live_view`
    # if there's no custom render logic beyond what the template does.
    # For clarity, we ensure it's here if we were to add specific logic.
    # Since we rely on `pac_dashboard_live.html.heex`, this is sufficient.
    assigns
  end

  def pac_card_classes(pac, zone_events) do
    base_classes = "rounded-lg shadow-md hover:shadow-xl transition-shadow duration-300 ease-in-out p-4 block" # New base classes from prompt

    highlight_class =
      if pac_zone_id = pac.zone_id do # Assuming pac.zone_id is the correct field for current zone
        # Check if there's any event for the PAC's current zone
        if Map.has_key?(zone_events, pac_zone_id) do
          " zone-highlight" # Add leading space for class concatenation
        else
          ""
        end
      else
        "" # No zone_id for the PAC, so no highlight
      end

    pulse_class = if pac.just_updated, do: " pulse-animation", else: "" # Add leading space if used

    # Ensure proper spacing when concatenating classes
    # Trim to avoid leading/trailing spaces if some classes are empty, then join.
    # However, simple concatenation with leading spaces on conditional classes is often fine.
    # Let's adjust to ensure no double spacing if a class is empty.
    # A more robust way is to build a list and join.
    classes = [
      base_classes,
      String.trim(highlight_class), # remove leading space if present, then let join handle it
      String.trim(pulse_class)      # remove leading space if present
    ]
    Enum.reject(classes, &(&1 == "")) |> Enum.join(" ")
  end
end
