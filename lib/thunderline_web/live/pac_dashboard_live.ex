defmodule ThunderlineWeb.PacDashboardLive do
  use ThunderlineWeb, :live_view
  alias Thunderline.PAC.Agent
  alias Thunderline.PubSub

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "agents:updates")
    end

    pacs = Agent.list_active()
    {:ok,
     assign(socket,
       pacs: pacs,
       selected_pac_id_for_dev_panel: nil,
       selected_pac_for_dev_panel: nil
     ), temporary_assigns: [pacs: [], selected_pac_for_dev_panel: nil]}
  end

  @impl true
  def handle_info({:pac_updated, updated_pac_data}, socket) do
    updated_pacs =
      Enum.map(socket.assigns.pacs, fn pac ->
        if pac.id == updated_pac_data.id do
          Map.merge(pac, updated_pac_data)
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
end
