defmodule ThunderlineWeb.MapLive do
  @moduledoc """
  Phoenix LiveView for real-time PAC tracking on Google Maps

  This LiveView handles:
  - Real-time PAC position updates
  - Google Maps integration via JavaScript hooks
  - Region-based PAC coordination
  - 3D grid to GPS coordinate mapping
  """

  use ThunderlineWeb, :live_view
  alias Thunderline.OKO.GridWorld
  alias Thunderline.Domain

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to PAC movement updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Thunderline.PubSub, "pac_movements")
      Phoenix.PubSub.subscribe(Thunderline.PubSub, "region_updates")
    end

    {:ok,
     socket
     |> assign(:pacs, [])
     |> assign(:current_region, "sector_alpha")
     # NYC default
     |> assign(:map_center, %{lat: 40.7128, lng: -74.0060})
     |> assign(:zoom_level, 12)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    region_id = Map.get(params, "region", "sector_alpha")

    {:noreply,
     socket
     |> assign(:current_region, region_id)
     |> load_region_pacs(region_id)}
  end

  @impl true
  def handle_event("update_pacs", _params, socket) do
    {:noreply,
     socket
     |> load_region_pacs(socket.assigns.current_region)
     |> push_pac_positions()}
  end

  @impl true
  def handle_event("place_pac", %{"lat" => lat, "lng" => lng}, socket) do
    # Convert GPS to grid coordinates
    {x, y, z} = GridWorld.gps_to_grid(lat, lng)

    pac_id = Ash.UUID.generate()
    tick_id = :os.system_time(:millisecond)

    # Create new PAC position
    case Domain.create(GridWorld, %{
           pac_id: pac_id,
           lat: lat,
           lng: lng,
           x: x,
           y: y,
           z: z,
           region_id: socket.assigns.current_region,
           tick_id: tick_id
         }) do
      {:ok, position} ->
        # Broadcast to other viewers
        Phoenix.PubSub.broadcast(Thunderline.PubSub, "pac_movements", {:pac_placed, position})

        {:noreply,
         socket
         |> load_region_pacs(socket.assigns.current_region)
         |> push_pac_positions()}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to place PAC")}
    end
  end

  @impl true
  def handle_event("move_pac", %{"pac_id" => pac_id, "lat" => lat, "lng" => lng}, socket) do
    # Convert GPS to grid coordinates
    {x, y, z} = GridWorld.gps_to_grid(lat, lng)
    tick_id = :os.system_time(:millisecond)

    # Find existing PAC position
    case Domain.read!(GridWorld, action: :get_pac_position, pac_id: pac_id) do
      [position | _] ->
        case Domain.update(position, %{
               lat: lat,
               lng: lng,
               x: x,
               y: y,
               z: z,
               tick_id: tick_id
             }) do
          {:ok, updated_position} ->
            # Broadcast movement
            Phoenix.PubSub.broadcast(
              Thunderline.PubSub,
              "pac_movements",
              {:pac_moved, updated_position}
            )

            {:noreply,
             socket
             |> load_region_pacs(socket.assigns.current_region)
             |> push_pac_positions()}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to move PAC")}
        end

      [] ->
        {:noreply, put_flash(socket, :error, "PAC not found")}
    end
  end

  @impl true
  def handle_event("remove_pac", %{"pac_id" => pac_id}, socket) do
    case Domain.read!(GridWorld, action: :get_pac_position, pac_id: pac_id) do
      [position | _] ->
        Domain.destroy(position)

        Phoenix.PubSub.broadcast(Thunderline.PubSub, "pac_movements", {:pac_removed, pac_id})

        {:noreply,
         socket
         |> load_region_pacs(socket.assigns.current_region)
         |> push_pac_positions()}

      [] ->
        {:noreply, socket}
    end
  end

  # Handle real-time PAC movement broadcasts
  @impl true
  def handle_info({:pac_placed, position}, socket) do
    if position.region_id == socket.assigns.current_region do
      {:noreply,
       socket
       |> load_region_pacs(socket.assigns.current_region)
       |> push_pac_positions()}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:pac_moved, position}, socket) do
    if position.region_id == socket.assigns.current_region do
      {:noreply,
       socket
       |> load_region_pacs(socket.assigns.current_region)
       |> push_pac_positions()}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:pac_removed, _pac_id}, socket) do
    {:noreply,
     socket
     |> load_region_pacs(socket.assigns.current_region)
     |> push_pac_positions()}
  end

  # Private functions

  defp load_region_pacs(socket, region_id) do
    pacs = Domain.read!(GridWorld, action: :get_region_pacs, region_id: region_id)
    assign(socket, :pacs, pacs)
  end

  defp push_pac_positions(socket) do
    push_event(socket, "update_pacs", %{
      pacs: socket.assigns.pacs,
      region: socket.assigns.current_region
    })
  end
end
