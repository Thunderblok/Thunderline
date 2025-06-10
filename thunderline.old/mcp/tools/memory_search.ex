defmodule Thunderline.MCP.Tools.MemorySearch do
  @moduledoc """
  Tool for searching through PAC memories and experiences.

  Enables PACs to query their stored memories using semantic search,
  helping them recall relevant past experiences for decision making.
  """

  @behaviour Thunderline.MCP.Tool

  alias Thunderline.Memory.{Manager, VectorSearch}

  @impl true
  def execute(params) do
    %{
      "pac_id" => pac_id,
      "query" => query,
      "limit" => limit,
      "filters" => filters
    } = params

    limit = limit || 5
    filters = filters || %{}

    search_memories(pac_id, query, limit, filters)
  end

  defp search_memories(pac_id, query, limit, filters) do
    with {:ok, results} <- perform_semantic_search(pac_id, query, limit, filters),
         processed_results <- process_search_results(results, query) do

      result = %{
        type: "memory_search",
        query: query,
        results_count: length(processed_results),
        memories: processed_results,
        search_metadata: %{
          pac_id: pac_id,
          filters_applied: filters,
          limit: limit,
          timestamp: DateTime.utc_now()
        }
      }

      {:ok, result}
    else
      {:error, reason} ->
        {:error, {:memory_search_failed, reason}}
    end
  end

  defp perform_semantic_search(pac_id, query, limit, filters) do
    # Use vector search for semantic similarity
    case VectorSearch.search_memories(pac_id, query, limit) do
      {:ok, vector_results} ->
        # Apply additional filters
        filtered_results = apply_filters(vector_results, filters)
        {:ok, filtered_results}

      {:error, reason} ->
        # Fallback to keyword search if vector search fails
        fallback_search(pac_id, query, limit, filters)
    end
  end

  defp fallback_search(pac_id, query, limit, filters) do
    # Simple keyword-based search as fallback
    case Manager.search_memories_by_keywords(pac_id, query, limit) do
      {:ok, results} ->
        filtered_results = apply_filters(results, filters)
        {:ok, filtered_results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp apply_filters(memories, filters) do
    memories
    |> filter_by_type(filters["type"])
    |> filter_by_importance(filters["min_importance"])
    |> filter_by_date_range(filters["date_range"])
    |> filter_by_tags(filters["tags"])
    |> filter_by_emotional_valence(filters["emotional_valence"])
  end

  defp filter_by_type(memories, nil), do: memories
  defp filter_by_type(memories, type) do
    Enum.filter(memories, &(&1.type == type))
  end

  defp filter_by_importance(memories, nil), do: memories
  defp filter_by_importance(memories, min_importance) do
    Enum.filter(memories, &(&1.importance >= min_importance))
  end

  defp filter_by_date_range(memories, nil), do: memories
  defp filter_by_date_range(memories, %{"start" => start_date, "end" => end_date}) do
    {:ok, start_dt, _} = DateTime.from_iso8601(start_date)
    {:ok, end_dt, _} = DateTime.from_iso8601(end_date)

    Enum.filter(memories, fn memory ->
      case DateTime.from_iso8601(memory.timestamp) do
        {:ok, memory_dt, _} ->
          DateTime.compare(memory_dt, start_dt) != :lt and
          DateTime.compare(memory_dt, end_dt) != :gt
        _ -> true  # Include if timestamp parsing fails
      end
    end)
  end
  defp filter_by_date_range(memories, _), do: memories

  defp filter_by_tags(memories, nil), do: memories
  defp filter_by_tags(memories, tags) when is_list(tags) do
    Enum.filter(memories, fn memory ->
      memory_tags = memory.tags || []
      Enum.any?(tags, &(&1 in memory_tags))
    end)
  end
  defp filter_by_tags(memories, _), do: memories

  defp filter_by_emotional_valence(memories, nil), do: memories
  defp filter_by_emotional_valence(memories, valence_filter) do
    case valence_filter do
      "positive" ->
        Enum.filter(memories, &(&1.emotional_valence > 0))
      "negative" ->
        Enum.filter(memories, &(&1.emotional_valence < 0))
      "neutral" ->
        Enum.filter(memories, &(abs(&1.emotional_valence) < 0.2))
      _ ->
        memories
    end
  end

  defp process_search_results(memories, query) do
    memories
    |> Enum.map(&enrich_memory_result(&1, query))
    |> Enum.sort_by(&(&1.relevance_score), :desc)
  end

  defp enrich_memory_result(memory, query) do
    # Add search-specific metadata
    relevance_score = calculate_relevance_score(memory, query)
    context_snippet = extract_context_snippet(memory)

    memory
    |> Map.put(:relevance_score, relevance_score)
    |> Map.put(:context_snippet, context_snippet)
    |> Map.put(:time_ago, calculate_time_ago(memory.timestamp))
    |> Map.put(:summary, generate_memory_summary(memory))
  end

  defp calculate_relevance_score(memory, query) do
    # Calculate relevance based on multiple factors
    base_score = memory.importance || 0.5

    # Text similarity (simple keyword matching as fallback)
    text_score = calculate_text_similarity(memory, query)

    # Recency score (more recent memories get slight boost)
    recency_score = calculate_recency_score(memory.timestamp)

    # Emotional relevance
    emotional_score = if memory.emotional_valence > 0.5, do: 0.1, else: 0.0

    # Combine scores
    total_score = base_score * 0.5 + text_score * 0.3 + recency_score * 0.1 + emotional_score
    Float.round(total_score, 3)
  end

  defp calculate_text_similarity(memory, query) do
    # Simple keyword-based similarity
    query_words =
      query
      |> String.downcase()
      |> String.split(~r/\W+/, trim: true)
      |> MapSet.new()

    memory_text = [
      memory.description || "",
      Enum.join(memory.tags || [], " "),
      memory.context || ""
    ]
    |> Enum.join(" ")
    |> String.downcase()

    memory_words =
      memory_text
      |> String.split(~r/\W+/, trim: true)
      |> MapSet.new()

    intersection_size = MapSet.intersection(query_words, memory_words) |> MapSet.size()
    union_size = MapSet.union(query_words, memory_words) |> MapSet.size()

    if union_size > 0, do: intersection_size / union_size, else: 0.0
  end

  defp calculate_recency_score(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> calculate_recency_score(dt)
      _ -> 0.0
    end
  end

  defp calculate_recency_score(%DateTime{} = timestamp) do
    hours_ago = DateTime.diff(DateTime.utc_now(), timestamp, :hour)
    max(0.0, 1.0 - (hours_ago / 168))  # Decay over a week
  end

  defp calculate_recency_score(_), do: 0.0

  defp extract_context_snippet(memory) do
    # Extract a brief context snippet for display
    description = memory.description || ""

    if String.length(description) > 100 do
      String.slice(description, 0, 97) <> "..."
    else
      description
    end
  end

  defp calculate_time_ago(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> calculate_time_ago(dt)
      _ -> "unknown time"
    end
  end

  defp calculate_time_ago(%DateTime{} = timestamp) do
    diff_seconds = DateTime.diff(DateTime.utc_now(), timestamp, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} minutes ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)} hours ago"
      diff_seconds < 604800 -> "#{div(diff_seconds, 86400)} days ago"
      true -> "over a week ago"
    end
  end

  defp calculate_time_ago(_), do: "unknown time"

  defp generate_memory_summary(memory) do
    # Generate a brief summary based on memory type and content
    case memory.type do
      :action ->
        "Performed #{memory.action}: #{memory.description}"
      :social ->
        "Social interaction: #{memory.description}"
      :learning ->
        "Learned: #{memory.learning || memory.description}"
      :creative ->
        "Created: #{memory.creation || memory.description}"
      :discovery ->
        "Discovered: #{memory.discovery || memory.description}"
      :failure ->
        "Failed attempt: #{memory.description}"
      _ ->
        memory.description || "Memory without description"
    end
  end
end
