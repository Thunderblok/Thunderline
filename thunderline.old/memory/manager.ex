defmodule Thunderline.Memory.Manager do
  @moduledoc """
  Semantic Memory Management for Thunderline PACs.

  Provides vector-based memory storage and retrieval for PACs, enabling:
  - Semantic similarity search for relevant context
  - Memory clustering and organization
  - Temporal decay and importance weighting
  - Memory consolidation and archival

  Integrates with pgvector for efficient similarity operations and
  supports both synchronous and asynchronous memory operations.
  """

  use GenServer
  require Logger

  alias Thunderline.{Memory, Repo}
  alias Thunderline.Memory.{Embedding, VectorSearch}

  # ========================================
  # Public API
  # ========================================

  @doc """
  Store a new memory for a PAC with automatic embedding generation.

  ## Examples

      iex> Thunderline.Memory.Manager.store_memory("pac_123", "I discovered a hidden cave", %{location: "forest_zone"})
      {:ok, %Memory{}}
  """
  def store_memory(pac_id, content, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:store_memory, pac_id, content, metadata})
  end

  @doc """
  Retrieve memories similar to the given query content.

  ## Examples

      iex> Thunderline.Memory.Manager.recall_memories("pac_123", "caves and exploration", limit: 5)
      {:ok, [%Memory{similarity: 0.85, content: "I discovered a hidden cave"}, ...]}
  """
  def recall_memories(pac_id, query_content, opts \\ []) do
    GenServer.call(__MODULE__, {:recall_memories, pac_id, query_content, opts})
  end

  @doc """
  Get recent memories for a PAC (chronological order).

  ## Examples

      iex> Thunderline.Memory.Manager.recent_memories("pac_123", limit: 10)
      {:ok, [%Memory{}, ...]}
  """
  def recent_memories(pac_id, opts \\ []) do
    GenServer.call(__MODULE__, {:recent_memories, pac_id, opts})
  end

  @doc """
  Get relevant memories for context (combines recent and important memories).

  ## Examples

      iex> Thunderline.Memory.Manager.get_relevant_memories("pac_123", limit: 10)
      [%Memory{}, ...]
  """
  def get_relevant_memories(pac_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    # Get recent memories and most important memories, then merge them
    case recent_memories(pac_id, limit: div(limit, 2)) do
      {:ok, recent} ->
        # For now, just return recent memories
        # TODO: Add importance-based filtering and merging
        recent
      {:error, _} ->
        []
    end
  end

  @doc """
  Get memory statistics for a PAC.

  ## Examples

      iex> Thunderline.Memory.Manager.memory_stats("pac_123")
      {:ok, %{total_memories: 150, oldest_memory: ~U[2024-01-01 00:00:00Z], ...}}
  """
  def memory_stats(pac_id) do
    GenServer.call(__MODULE__, {:memory_stats, pac_id})
  end

  @doc """
  Archive old memories based on age and importance.
  """
  def archive_memories(pac_id, opts \\ []) do
    GenServer.call(__MODULE__, {:archive_memories, pac_id, opts})
  end

  # ========================================
  # GenServer Implementation
  # ========================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    state = %{
      embedding_model: Keyword.get(opts, :embedding_model, "all-MiniLM-L6-v2"),
      vector_dimensions: Keyword.get(opts, :vector_dimensions, 384),
      similarity_threshold: Keyword.get(opts, :similarity_threshold, 0.7),
      max_memories: Keyword.get(opts, :max_memories, 1000),
      batch_size: Keyword.get(opts, :batch_size, 32)
    }

    Logger.info("Memory Manager started with model: #{state.embedding_model}")
    {:ok, state}
  end

  @impl true
  def handle_call({:store_memory, pac_id, content, metadata}, _from, state) do
    result = do_store_memory(pac_id, content, metadata, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:recall_memories, pac_id, query_content, opts}, _from, state) do
    result = do_recall_memories(pac_id, query_content, opts, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:recent_memories, pac_id, opts}, _from, state) do
    result = do_recent_memories(pac_id, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:memory_stats, pac_id}, _from, state) do
    result = do_memory_stats(pac_id)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:archive_memories, pac_id, opts}, _from, state) do
    result = do_archive_memories(pac_id, opts, state)
    {:reply, result, state}
  end

  # ========================================
  # Memory Operations
  # ========================================

  defp do_store_memory(pac_id, content, metadata, state) do
    # Generate embedding for the content
    case VectorSearch.generate_embedding(content, state.embedding_model) do
      {:ok, embedding_vector} ->
        # Create memory record
        memory_attrs = %{
          pac_id: pac_id,
          content: content,
          metadata: metadata,
          importance: calculate_importance(content, metadata),
          created_at: DateTime.utc_now()
        }

        # Store in database with embedding
        Repo.transaction(fn ->
          case Memory.create(memory_attrs) do
            {:ok, memory} ->
              # Store embedding vector
              embedding_attrs = %{
                memory_id: memory.id,
                vector: embedding_vector,
                model_used: state.embedding_model,
                dimensions: state.vector_dimensions
              }

              case Embedding.create(embedding_attrs) do
                {:ok, _embedding} ->
                  # Check memory limits and archive if needed
                  check_memory_limits(pac_id, state)
                  memory

                {:error, error} ->
                  Repo.rollback({:embedding_creation_failed, error})
              end

            {:error, error} ->
              Repo.rollback({:memory_creation_failed, error})
          end
        end)

      {:error, error} ->
        Logger.error("Failed to generate embedding for memory: #{inspect(error)}")
        {:error, :embedding_generation_failed}
    end
  end

  defp do_recall_memories(pac_id, query_content, opts, state) do
    limit = Keyword.get(opts, :limit, 10)
    threshold = Keyword.get(opts, :threshold, state.similarity_threshold)

    # Generate embedding for query
    case VectorSearch.generate_embedding(query_content, state.embedding_model) do
      {:ok, query_vector} ->
        # Search for similar memories
        VectorSearch.similarity_search(pac_id, query_vector, limit, threshold)

      {:error, error} ->
        Logger.error("Failed to generate query embedding: #{inspect(error)}")
        {:error, :query_embedding_failed}
    end
  end

  defp do_recent_memories(pac_id, opts) do
    limit = Keyword.get(opts, :limit, 20)

    query = from m in Memory,
      where: m.pac_id == ^pac_id and m.archived == false,
      order_by: [desc: m.created_at],
      limit: ^limit

    memories = Repo.all(query)
    {:ok, memories}
  rescue
    error ->
      Logger.error("Failed to fetch recent memories: #{inspect(error)}")
      {:error, :database_error}
  end

  defp do_memory_stats(pac_id) do
    stats_query = from m in Memory,
      where: m.pac_id == ^pac_id,
      select: %{
        total_memories: count(m.id),
        active_memories: count(m.id) |> filter(m.archived == false),
        archived_memories: count(m.id) |> filter(m.archived == true),
        oldest_memory: min(m.created_at),
        newest_memory: max(m.created_at),
        avg_importance: avg(m.importance)
      }

    case Repo.one(stats_query) do
      nil -> {:ok, %{total_memories: 0}}
      stats -> {:ok, stats}
    end
  rescue
    error ->
      Logger.error("Failed to calculate memory stats: #{inspect(error)}")
      {:error, :database_error}
  end

  defp do_archive_memories(pac_id, opts, state) do
    max_age_days = Keyword.get(opts, :max_age_days, 30)
    min_importance = Keyword.get(opts, :min_importance, 0.3)

    cutoff_date = DateTime.add(DateTime.utc_now(), -max_age_days * 24 * 60 * 60, :second)

    # Archive memories that are old and low importance
    archive_query = from m in Memory,
      where: m.pac_id == ^pac_id
        and m.created_at < ^cutoff_date
        and m.importance < ^min_importance
        and m.archived == false

    {archived_count, _} = Repo.update_all(archive_query, set: [archived: true, archived_at: DateTime.utc_now()])

    Logger.info("Archived #{archived_count} memories for PAC #{pac_id}")
    {:ok, %{archived_count: archived_count}}
  rescue
    error ->
      Logger.error("Failed to archive memories: #{inspect(error)}")
      {:error, :database_error}
  end

  # ========================================
  # Helper Functions
  # ========================================

  defp calculate_importance(content, metadata) do
    base_importance = 0.5

    # Increase importance based on content length and complexity
    length_bonus = min(String.length(content) / 1000, 0.3)

    # Increase importance for certain metadata
    metadata_bonus = case metadata do
      %{type: "discovery"} -> 0.2
      %{type: "interaction"} -> 0.15
      %{type: "achievement"} -> 0.25
      %{emotion: emotion} when emotion in ["joy", "surprise", "fear"] -> 0.1
      _ -> 0.0
    end

    # Keyword-based importance
    important_keywords = ["discovered", "learned", "met", "created", "important", "significant"]
    keyword_bonus = if Enum.any?(important_keywords, &String.contains?(String.downcase(content), &1)) do
      0.1
    else
      0.0
    end

    min(base_importance + length_bonus + metadata_bonus + keyword_bonus, 1.0)
  end

  defp check_memory_limits(pac_id, state) do
    # Count current active memories
    count_query = from m in Memory,
      where: m.pac_id == ^pac_id and m.archived == false,
      select: count(m.id)

    case Repo.one(count_query) do
      count when count > state.max_memories ->
        # Archive least important memories
        excess = count - state.max_memories

        archive_query = from m in Memory,
          where: m.pac_id == ^pac_id and m.archived == false,
          order_by: [asc: m.importance, asc: m.created_at],
          limit: ^excess

        {archived, _} = Repo.update_all(archive_query, set: [archived: true, archived_at: DateTime.utc_now()])

        Logger.info("Auto-archived #{archived} memories for PAC #{pac_id} due to limit")

      _ ->
        :ok
    end
  end
end
