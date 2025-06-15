defmodule ThunderlineWeb.PacDetailLive do
  use ThunderlineWeb, :live_view

  alias Thunderline.PAC.Agent
  alias Thunderline.Tick.Log
  alias Thunderline.Memory.Manager
  alias Thunderline.PubSub

  @impl true
  def mount(%{"id" => pac_id}, _session, socket) do
    # Initial state
    socket =
      socket
      |> assign(:loading, true)
      |> assign(:pac_id, pac_id)
      |> assign(:pac, nil)
      |> assign(:tick_logs, [])
      |> assign(:memory_graph, %{})
      |> assign(:page_title, "Loading PAC Details...")

    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "agents:updates")
      Phoenix.PubSub.subscribe(Thunderline.PubSub, "agent:" <> pac_id)
    end

    # Asynchronously load data or send message to self to load
    # For simplicity here, we'll load synchronously but structure for async
    pac = Agent.get_by_id(pac_id)
    tick_logs = if pac, do: Log.for_agent_recent(pac_id), else: []
    memory_graph = if pac, do: fetch_memory_graph(pac_id), else: %{}

    new_page_title =
      if pac do
        pac.name <> " Details"
      else
        "PAC Not Found"
      end

    socket =
      socket
      |> assign(:pac, pac)
      |> assign(:tick_logs, tick_logs)
      |> assign(:memory_graph, memory_graph)
      |> assign(:page_title, new_page_title)
      |> assign(:loading, false)

    # The temporary_assigns for :pac should reflect that it might be nil if not found
    # and shouldn't be reset if it's successfully loaded.
    # However, the initial setup of temporary_assigns for :pac being nil is if it's not yet loaded.
    # If it's loaded (even if to nil because it's not found), it's no longer "temporary" in that sense.
    # For now, keeping the original temporary_assigns, but this might need refinement
    # based on specific desired behavior of temporary_assigns with error states.
    {:ok, socket, temporary_assigns: [pac: nil, tick_logs: [], memory_graph: %{}]}
  end

  @impl true
  def handle_info({:pac_updated, updated_pac_data}, socket) do
    current_pac_id = socket.assigns.pac_id
    if updated_pac_data.id == current_pac_id do
      # The PAC we are currently viewing has been updated.
      # Re-fetch its details, logs, and memory graph.
      # We assume `updated_pac_data` might just be a summary or partial update.
      pac = Agent.get_by_id(current_pac_id)
      tick_logs = Log.for_agent_recent(current_pac_id)
      memory_graph = fetch_memory_graph(current_pac_id)

      socket =
        socket
        |> assign(:pac, pac)
        |> assign(:tick_logs, tick_logs)
        |> assign(:memory_graph, memory_graph)
        |> assign_new(:page_title, fn -> if(pac, do: pac.name <> " Details", else: "PAC Detail") end)

      {:noreply, socket}
    else
      # Update is for a different PAC, ignore.
      {:noreply, socket}
    end
  end

  defp fetch_memory_graph(pac_id) do
    if function_exported?(Manager, :get_memory_graph, 1) do
      Manager.get_memory_graph(pac_id)
    else
      %{nodes: [], edges: []}
    end
  end

  @impl true
  def render(assigns) do
    # This render function is provided by use ThunderlineWeb, :live_view
    # It will use pac_detail_live.html.heex template.
    # We don't need to redefine it unless we have very specific render logic here.
    assigns
  end

  # Handle direct tick updates for the currently viewed PAC
  @impl true
  def handle_info({:tick_update, %{agent: agent_data, result: res}}, socket) do
    current_pac_id = socket.assigns.pac_id

    # Ensure @pac is not nil before attempting to merge, as this handle_info
    # could theoretically be called before mount finishes or if PAC was not found.
    if socket.assigns.pac && agent_data.id == socket.assigns.pac_id do
      updated_pac =
        socket.assigns.pac
        |> Map.merge(agent_data) # agent_data should be the agent resource map
        |> Map.put(:last_tick_result, res)

      tick_logs = Log.for_agent_recent(socket.assigns.pac_id)

      socket =
        socket
        |> assign(:pac, updated_pac)
        |> assign(:tick_logs, tick_logs)

      {:noreply, socket}
    else
      # Tick update is for a different PAC or PAC not loaded, ignore.
      {:noreply, socket}
    end
  end
end
