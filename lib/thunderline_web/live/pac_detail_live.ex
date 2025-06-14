defmodule ThunderlineWeb.PacDetailLive do
  use ThunderlineWeb, :live_view

  alias Thunderline.PAC.Agent
  alias Thunderline.Tick.Log
  alias Thunderline.Memory.Manager
  alias Thunderline.PubSub

  @impl true
  def mount(%{"id" => pac_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "agents:updates")
    end

    pac = Agent.get_by_id(pac_id)
    tick_logs = Log.for_agent_recent(pac_id)
    memory_graph = fetch_memory_graph(pac_id)

    socket =
      socket
      |> assign(:pac_id, pac_id) # Store pac_id for handle_info
      |> assign(:pac, pac)
      |> assign(:tick_logs, tick_logs)
      |> assign(:memory_graph, memory_graph)
      |> assign_new(:page_title, fn -> if(pac, do: pac.name <> " Details", else: "PAC Detail") end)

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
    ~H"""
    <div>PAC Detail Page for <%= @pac.name %></div>
    """
  end
end
