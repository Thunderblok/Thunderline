defmodule Thunderline.Memory.VectorSearch do
  @moduledoc """
  Vector similarity search implementation for Thunderline memory system.

  Provides efficient semantic similarity search using pgvector and
  sentence transformer embeddings. Supports both synchronous and
  asynchronous operations for memory retrieval.
  """

  require Logger

  alias Thunderline.{Memory, Repo}
  alias Thunderline.Memory.Embedding

  # ========================================
  # Embedding Generation
  # ========================================

  @doc """
  Generate embedding vector for text content.

  Currently uses a placeholder implementation. In production, this would
  integrate with actual embedding models like Sentence Transformers.
  """
  def generate_embedding(content, model \\ "all-MiniLM-L6-v2") do
    # TODO: Integrate with actual embedding service
    # For now, return a mock embedding vector
    case mock_embedding_generation(content, model) do
      {:ok, vector} -> {:ok, vector}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generate embeddings for multiple content pieces in batch.
  More efficient for bulk operations.
  """
  def generate_embeddings_batch(contents, model \\ "all-MiniLM-L6-v2") do
    # TODO: Implement actual batch embedding generation
    results = Enum.map(contents, &generate_embedding(&1, model))

    # Check if all succeeded
    case Enum.find(results, fn {status, _} -> status == :error end) do
      nil ->
        vectors = Enum.map(results, fn {:ok, vector} -> vector end)
        {:ok, vectors}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ========================================
  # Similarity Search
  # ========================================

  @doc """
  Search for memories similar to the query vector.

  Uses cosine similarity with pgvector for efficient computation.
  """
  def similarity_search(pac_id, query_vector, limit \\ 10, threshold \\ 0.7) do
    # Build similarity query using pgvector
    similarity_query = """
    SELECT m.*, e.vector <=> $1::vector AS similarity
    FROM memories m
    JOIN embeddings e ON m.id = e.memory_id
    WHERE m.pac_id = $2
      AND m.archived = false
      AND (e.vector <=> $1::vector) < $3
    ORDER BY e.vector <=> $1::vector
    LIMIT $4
    """

    # Convert similarity threshold (higher = more similar) to distance threshold (lower = more similar)
    distance_threshold = 1.0 - threshold

    case Repo.query(similarity_query, [query_vector, pac_id, distance_threshold, limit]) do
      {:ok, %{rows: rows, columns: columns}} ->
        memories = Enum.map(rows, fn row ->
          # Convert row to memory struct
          row_map = Enum.zip(columns, row) |> Map.new()
          memory = struct(Memory, row_map)

          # Add similarity score (convert distance back to similarity)
          similarity = 1.0 - row_map["similarity"]
          Map.put(memory, :similarity, similarity)
        end)

        {:ok, memories}

      {:error, error} ->
        Logger.error("Similarity search failed: #{inspect(error)}")
        {:error, :search_failed}
    end
  end

  @doc """
  Find memories within a specific similarity range.
  """
  def similarity_range_search(pac_id, query_vector, min_similarity, max_similarity, limit \\ 50) do
    min_distance = 1.0 - max_similarity
    max_distance = 1.0 - min_similarity

    range_query = """
    SELECT m.*, e.vector <=> $1::vector AS similarity
    FROM memories m
    JOIN embeddings e ON m.id = e.memory_id
    WHERE m.pac_id = $2
      AND m.archived = false
      AND (e.vector <=> $1::vector) BETWEEN $3 AND $4
    ORDER BY e.vector <=> $1::vector
    LIMIT $5
    """

    case Repo.query(range_query, [query_vector, pac_id, min_distance, max_distance, limit]) do
      {:ok, %{rows: rows, columns: columns}} ->
        memories = Enum.map(rows, fn row ->
          row_map = Enum.zip(columns, row) |> Map.new()
          memory = struct(Memory, row_map)
          similarity = 1.0 - row_map["similarity"]
          Map.put(memory, :similarity, similarity)
        end)

        {:ok, memories}

      {:error, error} ->
        Logger.error("Range search failed: #{inspect(error)}")
        {:error, :search_failed}
    end
  end

  # ========================================
  # Clustering and Analysis
  # ========================================

  @doc """
  Cluster memories by similarity for a PAC.

  Groups related memories together for better organization.
  """
  def cluster_memories(pac_id, cluster_count \\ 5) do
    # Get all embeddings for the PAC
    embeddings_query = """
    SELECT m.id, m.content, e.vector
    FROM memories m
    JOIN embeddings e ON m.id = e.memory_id
    WHERE m.pac_id = $1 AND m.archived = false
    """

    case Repo.query(embeddings_query, [pac_id]) do
      {:ok, %{rows: rows}} ->
        # Simple clustering using K-means approach
        # TODO: Implement proper clustering algorithm
        clusters = simple_clustering(rows, cluster_count)
        {:ok, clusters}

      {:error, error} ->
        Logger.error("Clustering failed: #{inspect(error)}")
        {:error, :clustering_failed}
    end
  end

  @doc """
  Find the most representative memory in a cluster.
  """
  def find_cluster_centroid(memory_ids) do
    # Calculate average vector for memories in cluster
    avg_vector_query = """
    SELECT AVG(e.vector) as centroid_vector
    FROM embeddings e
    WHERE e.memory_id = ANY($1)
    """

    case Repo.query(avg_vector_query, [memory_ids]) do
      {:ok, %{rows: [[centroid_vector]]}} ->
        # Find memory closest to centroid
        find_closest_to_vector(memory_ids, centroid_vector)

      {:error, error} ->
        Logger.error("Centroid calculation failed: #{inspect(error)}")
        {:error, :centroid_calculation_failed}
    end
  end

  # ========================================
  # Performance and Maintenance
  # ========================================

  @doc """
  Rebuild vector index for improved performance.
  """
  def rebuild_index() do
    # Rebuild pgvector index
    index_query = """
    REINDEX INDEX CONCURRENTLY IF EXISTS embeddings_vector_idx;
    """

    case Repo.query(index_query, []) do
      {:ok, _} ->
        Logger.info("Vector index rebuilt successfully")
        :ok

      {:error, error} ->
        Logger.error("Index rebuild failed: #{inspect(error)}")
        {:error, :index_rebuild_failed}
    end
  end

  @doc """
  Get vector index statistics.
  """
  def index_stats() do
    stats_query = """
    SELECT
      schemaname,
      tablename,
      indexname,
      idx_size,
      idx_tuple_read,
      idx_tuple_fetch
    FROM pg_stat_user_indexes
    WHERE indexname LIKE '%vector%'
    """

    case Repo.query(stats_query, []) do
      {:ok, %{rows: rows, columns: columns}} ->
        stats = Enum.map(rows, fn row ->
          Enum.zip(columns, row) |> Map.new()
        end)

        {:ok, stats}

      {:error, error} ->
        Logger.error("Failed to get index stats: #{inspect(error)}")
        {:error, :stats_retrieval_failed}
    end
  end

  # ========================================
  # Private Helper Functions
  # ========================================

  # Mock embedding generation for development
  # TODO: Replace with actual embedding service integration
  defp mock_embedding_generation(content, _model) do
    # Generate a deterministic but pseudo-random vector based on content
    hash = :crypto.hash(:sha256, content)

    # Convert hash to 384-dimensional vector (matching sentence transformers)
    vector = for <<byte <- hash>>, into: [] do
      # Normalize to [-1, 1] range
      (byte - 128) / 128.0
    end

    # Pad or truncate to exactly 384 dimensions
    vector = case length(vector) do
      len when len < 384 ->
        padding = for _ <- 1..(384 - len), do: 0.0
        vector ++ padding

      len when len > 384 ->
        Enum.take(vector, 384)

      _ ->
        vector
    end

    {:ok, vector}
  rescue
    error ->
      Logger.error("Mock embedding generation failed: #{inspect(error)}")
      {:error, :embedding_generation_failed}
  end

  # Simple clustering implementation
  # TODO: Replace with proper clustering algorithm
  defp simple_clustering(rows, cluster_count) when length(rows) <= cluster_count do
    # If we have fewer memories than clusters, each memory is its own cluster
    Enum.with_index(rows, fn {id, content, _vector}, index ->
      %{
        cluster_id: index,
        memories: [%{id: id, content: content}],
        size: 1
      }
    end)
  end

  defp simple_clustering(rows, cluster_count) do
    # Randomly assign memories to clusters for now
    # TODO: Implement K-means or similar algorithm
    clusters = for i <- 0..(cluster_count - 1), do: %{cluster_id: i, memories: [], size: 0}

    rows
    |> Enum.with_index()
    |> Enum.reduce(clusters, fn {{id, content, _vector}, index}, acc ->
      cluster_index = rem(index, cluster_count)

      List.update_at(acc, cluster_index, fn cluster ->
        memory = %{id: id, content: content}
        %{
          cluster
          | memories: [memory | cluster.memories],
            size: cluster.size + 1
        }
      end)
    end)
  end

  defp find_closest_to_vector(memory_ids, target_vector) do
    closest_query = """
    SELECT m.id, m.content, e.vector <=> $1::vector as distance
    FROM memories m
    JOIN embeddings e ON m.id = e.memory_id
    WHERE m.id = ANY($2)
    ORDER BY e.vector <=> $1::vector
    LIMIT 1
    """

    case Repo.query(closest_query, [target_vector, memory_ids]) do
      {:ok, %{rows: [[id, content, _distance]]}} ->
        {:ok, %{id: id, content: content}}

      {:error, error} ->
        Logger.error("Failed to find closest memory: #{inspect(error)}")
        {:error, :closest_search_failed}
    end
  end
end
