defmodule Thunderline.MCP.Tools.Memory do
  @moduledoc """
  MCP tools for memory operations.
  """

  alias Thunderline.Memory.Manager

  def search(arguments, _session_id) do
    query = Map.get(arguments, "query")
    agent_id = Map.get(arguments, "agent_id")
    limit = Map.get(arguments, "limit", 10)

    case Manager.search(agent_id, query, limit: limit) do
      {:ok, results} ->
        formatted_results =
          Enum.map(results, fn memory ->
            %{
              id: memory.id,
              content: memory.content,
              tags: memory.tags,
              similarity_score: memory.similarity_score,
              created_at: memory.created_at
            }
          end)

        {:ok,
         %{
           query: query,
           results: formatted_results,
           count: length(formatted_results)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def store(arguments, _session_id) do
    content = Map.get(arguments, "content")
    agent_id = Map.get(arguments, "agent_id")
    tags = Map.get(arguments, "tags", [])

    case Manager.store(agent_id, content, tags: tags) do
      {:ok, memory_node} ->
        {:ok,
         %{
           id: memory_node.id,
           content: memory_node.content,
           tags: memory_node.tags,
           agent_id: memory_node.agent_id,
           created_at: memory_node.created_at
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_graph(arguments, _session_id) do
    agent_id = Map.get(arguments, "agent_id")
    depth = Map.get(arguments, "depth", 2)

    case Manager.get_memory_graph(agent_id, depth: depth) do
      {:ok, graph} ->
        {:ok,
         %{
           agent_id: agent_id,
           nodes:
             Enum.map(graph.nodes, fn node ->
               %{
                 id: node.id,
                 content: node.content,
                 tags: node.tags,
                 importance: node.importance
               }
             end),
           edges:
             Enum.map(graph.edges, fn edge ->
               %{
                 from: edge.from_id,
                 to: edge.to_id,
                 relationship: edge.relationship,
                 strength: edge.strength
               }
             end)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
