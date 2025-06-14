defmodule ThunderlineWeb.MemoryController do
  use ThunderlineWeb, :controller

  alias Thunderline.Memory.Manager, as: MemoryManager

  action_fallback ThunderlineWeb.FallbackController

  def search(conn, %{"query" => query, "agent_id" => agent_id} = params) do
    limit = params["limit"] || 10
    threshold = params["threshold"] || 0.8

    case MemoryManager.search_memory(query, agent_id, limit: limit, threshold: threshold) do
      {:ok, memories} ->
        json(conn, %{data: memories})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def store(conn, %{"content" => content, "agent_id" => agent_id} = params) do
    memory_params = %{
      content: content,
      agent_id: agent_id,
      tags: params["tags"] || [],
      importance: params["importance"] || 0.5,
      context: params["context"] || %{}
    }

    case MemoryManager.store_memory(content, agent_id, memory_params) do
      {:ok, memory} ->
        conn
        |> put_status(:created)
        |> json(%{data: memory})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def get_graph(conn, %{"agent_id" => agent_id}) do
    case MemoryManager.get_memory_graph(agent_id) do
      {:ok, graph} ->
        json(conn, %{data: graph})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
end
