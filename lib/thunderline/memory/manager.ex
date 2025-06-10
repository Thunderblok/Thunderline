defmodule Thunderline.Memory.Manager do
  @moduledoc """
  Memory Manager - Coordinates memory storage, retrieval, and graph operations.
  """

  use GenServer
  require Logger

  alias Thunderline.Memory.{MemoryNode, MemoryEdge}
  alias Thunderline.Domain

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Memory Manager started")
    {:ok, %{}}
  end

  # Client API

  @doc """
  Store content in agent memory.
  """
  def store(agent_id, content, opts \\ []) do
    GenServer.call(__MODULE__, {:store, agent_id, content, opts})
  end

  @doc """
  Search agent memory by content similarity.
  """
  def search(agent_id, query, opts \\ []) do
    GenServer.call(__MODULE__, {:search, agent_id, query, opts})
  end

  @doc """
  Get memory graph for an agent.
  """
  def get_memory_graph(agent_id, opts \\ []) do
    GenServer.call(__MODULE__, {:get_memory_graph, agent_id, opts})
  end

  @doc """
  Create a connection between two memory nodes.
  """
  def connect_memories(from_node_id, to_node_id, relationship, opts \\ []) do
    GenServer.call(__MODULE__, {:connect_memories, from_node_id, to_node_id, relationship, opts})
  end

  @doc """
  Consolidate and prune agent memories.
  """
  def consolidate_memories(agent_id) do
    GenServer.call(__MODULE__, {:consolidate_memories, agent_id})
  end

  # Server Callbacks

  def handle_call({:store, agent_id, content, opts}, _from, state) do
    case store_memory_impl(agent_id, content, opts) do
      {:ok, memory_node} -> {:reply, {:ok, memory_node}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:search, agent_id, query, opts}, _from, state) do
    case search_memory_impl(agent_id, query, opts) do
      {:ok, results} -> {:reply, {:ok, results}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_memory_graph, agent_id, opts}, _from, state) do
    case get_memory_graph_impl(agent_id, opts) do
      {:ok, graph} -> {:reply, {:ok, graph}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:connect_memories, from_node_id, to_node_id, relationship, opts}, _from, state) do
    case connect_memories_impl(from_node_id, to_node_id, relationship, opts) do
      {:ok, edge} -> {:reply, {:ok, edge}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:consolidate_memories, agent_id}, _from, state) do
    case consolidate_memories_impl(agent_id) do
      {:ok, result} -> {:reply, {:ok, result}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  # Private Implementation

  defp store_memory_impl(agent_id, content, opts) do
    tags = Keyword.get(opts, :tags, [])
    memory_type = Keyword.get(opts, :memory_type, :episodic)
    importance = Keyword.get(opts, :importance, 0.5)
    summary = Keyword.get(opts, :summary, generate_summary(content))

    MemoryNode.create(content, agent_id,
      tags: tags,
      memory_type: memory_type,
      importance: Decimal.new(to_string(importance)),
      summary: summary
    )
  end

  defp search_memory_impl(agent_id, query, opts) do
    limit = Keyword.get(opts, :limit, 10)
    threshold = Keyword.get(opts, :threshold, 0.7)

    # Generate embedding for the query
    case generate_embedding(query) do
      {:ok, query_embedding} ->
        # Find similar memories
        case MemoryNode.find_similar(
          query_embedding,
          limit,
          Decimal.new(to_string(threshold))
        ) do
          {:ok, similar_nodes} ->
            # Filter by agent and add similarity scores
            agent_memories = Enum.filter(similar_nodes, fn node ->
              node.agent_id == agent_id
            end)

            # Mark as accessed
            Enum.each(agent_memories, fn node ->
              MemoryNode.access(node)
            end)

            {:ok, agent_memories}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        # Fallback to tag-based search
        search_by_tags(agent_id, query, limit)
    end
  end

  defp get_memory_graph_impl(agent_id, opts) do
    depth = Keyword.get(opts, :depth, 2)

    case MemoryNode.list_by_agent(agent_id, load: [:outgoing_edges, :incoming_edges]) do
      {:ok, nodes} ->
        # Build graph with connections
        edges = nodes
        |> Enum.flat_map(fn node ->
          (node.outgoing_edges || []) ++ (node.incoming_edges || [])
        end)
        |> Enum.uniq_by(& &1.id)

        graph = %{
          nodes: nodes,
          edges: edges,
          agent_id: agent_id,
          depth: depth
        }

        {:ok, graph}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp connect_memories_impl(from_node_id, to_node_id, relationship, opts) do
    strength = Keyword.get(opts, :strength, 0.5)
    context = Keyword.get(opts, :context, %{})

    MemoryEdge.create(from_node_id, to_node_id, relationship,
      strength: Decimal.new(to_string(strength)),
      context: context
    )
  end

  defp consolidate_memories_impl(agent_id) do
    # Get all memories for the agent
    case MemoryNode.list_by_agent(agent_id) do
      {:ok, memories} ->
        # Find duplicates and low-importance memories
        duplicates = find_duplicate_memories(memories)
        low_importance = find_low_importance_memories(memories)

        # Merge duplicates and remove low-importance memories
        merge_results = merge_duplicate_memories(duplicates)
        prune_results = prune_low_importance_memories(low_importance)

        {:ok, %{
          duplicates_merged: length(merge_results),
          memories_pruned: length(prune_results),
          total_memories: length(memories) - length(prune_results)
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper functions

  defp generate_embedding(content) do
    # Placeholder - would integrate with actual embedding service
    {:ok, List.duplicate(0.0, 1536)}
  end

  defp generate_summary(content) do
    # Simple summary generation - could use AI
    words = String.split(content)
    if length(words) > 20 do
      words |> Enum.take(20) |> Enum.join(" ") |> Kernel.<>("...")
    else
      content
    end
  end

  defp search_by_tags(agent_id, query, limit) do
    # Simple tag-based search as fallback
    query_words = String.split(String.downcase(query))

    case MemoryNode.list_by_agent(agent_id) do
      {:ok, memories} ->
        matching_memories = Enum.filter(memories, fn memory ->
          memory_text = String.downcase(memory.content)
          Enum.any?(query_words, fn word ->
            String.contains?(memory_text, word)
          end)
        end)
        |> Enum.take(limit)

        {:ok, matching_memories}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_duplicate_memories(memories) do
    # Simple duplicate detection based on content similarity
    # In a real implementation, this would use embeddings
    []
  end

  defp find_low_importance_memories(memories) do
    # Find memories with low importance and low access count
    Enum.filter(memories, fn memory ->
      Decimal.lt?(memory.importance, Decimal.new("0.2")) and
      memory.access_count < 2
    end)
  end

  defp merge_duplicate_memories(duplicates) do
    # Merge duplicate memories - placeholder implementation
    []
  end

  defp prune_low_importance_memories(low_importance_memories) do
    # Remove low importance memories
    Enum.map(low_importance_memories, fn memory ->
      case MemoryNode.destroy(memory) do
        :ok -> memory.id
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
