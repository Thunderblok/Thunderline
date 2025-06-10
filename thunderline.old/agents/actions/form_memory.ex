defmodule Thunderline.Agents.Actions.FormMemory do
  @moduledoc """
  Action for forming new memories from PAC experiences.

  This action processes tick experiences to create meaningful memories by:
  - Extracting significant events and outcomes
  - Categorizing experiences by type and importance
  - Generating semantic embeddings for retrieval
  - Linking memories to emotional states and context
  - Storing memories in the vector database
  """

  use Jido.Action,
    name: "form_memory",
    description: "Form new memories from tick experiences",
    schema: [
      experience: [type: :map, required: true],
      pac_config: [type: :map, required: true],
      context: [type: :map, required: true],
      previous_state: [type: :map, default: %{}]
    ]

  require Logger
    alias Thunderline.Memory.Manager, as: MemoryManager
  alias Thunderline.Memory.VectorSearch
  alias Thunderline.MCP.PromptManager
  alias Thunderline.Agents.AIProvider

  @impl true
  def run(params, context) do
    %{
      experience: experience,
      pac_config: pac_config,
      context: tick_context,
      previous_state: prev_state
    } = params

    pac_id = pac_config.pac_id
    pac_name = pac_config.pac_name

    Logger.debug("Forming memories for PAC #{pac_name}")

    with {:ok, memory_candidates} <- extract_memory_candidates(experience, tick_context),
         {:ok, processed_memories} <- process_memories(memory_candidates, pac_config, prev_state),
         {:ok, stored_memories} <- store_memories(processed_memories, pac_id) do

      result = %{
        memories_formed: length(stored_memories),
        memory_types: extract_memory_types(stored_memories),
        significant_events: extract_significant_events(processed_memories),
        emotional_impact: calculate_emotional_impact(processed_memories),
        timestamp: DateTime.utc_now()
      }

      Logger.debug("Formed #{length(stored_memories)} memories for PAC #{pac_name}")
      {:ok, result}
    else
      {:error, reason} ->
        Logger.error("Memory formation failed for PAC #{pac_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Memory Extraction

  defp extract_memory_candidates(experience, context) do
    candidates = []

    # Extract action-based memories
    candidates = if experience.success do
      action_memory = create_action_memory(experience, context)
      [action_memory | candidates]
    else
      failure_memory = create_failure_memory(experience, context)
      [failure_memory | candidates]
    end

    # Extract discovery memories
    candidates = if discoveries = experience.execution_result[:discoveries] do
      discovery_memories = Enum.map(discoveries, &create_discovery_memory(&1, context))
      discovery_memories ++ candidates
    else
      candidates
    end

    # Extract social interaction memories
    candidates = if experience.execution_result[:type] == :social_interaction do
      social_memory = create_social_memory(experience, context)
      [social_memory | candidates]
    else
      candidates
    end

    # Extract learning memories
    candidates = if learning = experience.execution_result[:learning] do
      learning_memory = create_learning_memory(learning, context)
      [learning_memory | candidates]
    else
      candidates
    end

    # Extract creative memories
    candidates = if creation = experience.execution_result[:creation] do
      creative_memory = create_creative_memory(creation, context)
      [creative_memory | candidates]
    else
      candidates
    end

    {:ok, candidates}
  end

  defp create_action_memory(experience, context) do
    %{
      type: :action,
      action: experience.action,
      success: experience.success,
      description: experience.execution_result[:description] || "Performed #{experience.action}",
      energy_cost: experience.execution_result[:energy_cost] || 0,
      mood_effect: experience.execution_result[:mood_effect],
      context: extract_context_summary(context),
      importance: calculate_action_importance(experience),
      tags: generate_action_tags(experience),
      emotional_valence: calculate_emotional_valence(experience)
    }
  end

  defp create_failure_memory(experience, context) do
    %{
      type: :failure,
      action: experience.action,
      error: experience.error,
      description: "Failed to #{experience.action}: #{inspect(experience.error)}",
      context: extract_context_summary(context),
      importance: 0.7,  # Failures are important for learning
      tags: ["failure", "learning", experience.action],
      emotional_valence: -0.6
    }
  end

  defp create_discovery_memory(discovery, context) do
    %{
      type: :discovery,
      discovery: discovery,
      description: "Discovered: #{discovery}",
      context: extract_context_summary(context),
      importance: 0.8,  # Discoveries are highly important
      tags: ["discovery", "exploration", "learning"],
      emotional_valence: 0.7
    }
  end

  defp create_social_memory(experience, context) do
    %{
      type: :social,
      interaction_type: experience.execution_result[:interaction_type] || "general",
      description: experience.execution_result[:description],
      context: extract_context_summary(context),
      importance: calculate_social_importance(experience, context),
      tags: ["social", "interaction", "communication"],
      emotional_valence: calculate_social_valence(experience)
    }
  end

  defp create_learning_memory(learning, context) do
    %{
      type: :learning,
      learning: learning,
      description: "Learned: #{learning}",
      context: extract_context_summary(context),
      importance: 0.8,
      tags: ["learning", "knowledge", "growth"],
      emotional_valence: 0.5
    }
  end

  defp create_creative_memory(creation, context) do
    %{
      type: :creative,
      creation: creation,
      description: "Created: #{creation}",
      context: extract_context_summary(context),
      importance: 0.9,  # Creative achievements are very important
      tags: ["creative", "achievement", "expression"],
      emotional_valence: 0.8
    }
  end

  # Memory Processing
    defp process_memories(candidates, pac_config, prev_state) do
    processed =
      candidates
      |> Enum.map(&enrich_memory_with_ai(&1, pac_config, prev_state))
      |> Enum.filter(&filter_significant_memories/1)
      |> Enum.map(&add_temporal_context/1)
      |> Enum.map(&generate_embedding_text/1)

    {:ok, processed}
  end

  defp enrich_memory_with_ai(memory_candidate, pac_config, prev_state) do
    # Use AI to process the memory
    memory_context = %{
      pac_name: pac_config.pac_name,
      action: memory_candidate.action,
      result: memory_candidate.result,
      context_data: memory_candidate.context,
      traits: pac_config.traits
    }

    prompt = PromptManager.generate_memory_prompt(memory_context)

    case AIProvider.reason(prompt, memory_context) do
      {:ok, ai_memory} ->
        # Combine AI analysis with base memory data
        base_memory = %{
          pac_id: pac_config.pac_id,
          pac_name: pac_config.pac_name,
          timestamp: DateTime.utc_now(),
          pac_stats_snapshot: pac_config.stats,
          pac_traits: pac_config.traits,
          state_before: prev_state,
          action: memory_candidate.action,
          result: memory_candidate.result,
          context: memory_candidate.context
        }

        enriched_memory = Map.merge(base_memory, %{
          type: ai_memory["memory_type"],
          description: ai_memory["summary"],
          emotional_impact: ai_memory["emotional_impact"],
          insights: ai_memory["insights"] || [],
          importance: ai_memory["importance"] || 0.5,
          tags: ai_memory["tags"] || []
        })

        adjust_importance_for_personality(enriched_memory, pac_config.personality)

      {:error, _reason} ->
        # Fallback to rule-based memory formation
        enrich_memory_fallback(memory_candidate, pac_config, prev_state)
    end
  end

  defp enrich_memory_fallback(memory, pac_config, prev_state) do
    memory
    |> Map.put(:pac_id, pac_config.pac_id)
    |> Map.put(:pac_name, pac_config.pac_name)
    |> Map.put(:timestamp, DateTime.utc_now())
    |> Map.put(:pac_stats_snapshot, pac_config.stats)
    |> Map.put(:pac_traits, pac_config.traits)
    |> Map.put(:state_before, prev_state)
    |> Map.put(:type, "general")
    |> Map.put(:importance, 0.5)
    |> Map.put(:tags, ["fallback"])
    |> adjust_importance_for_personality(pac_config.personality)
  end

  defp filter_significant_memories(memory) do
    # Filter based on either importance or emotional impact
    importance = Map.get(memory, :importance, 0)
    emotional_impact = Map.get(memory, :emotional_impact, "neutral")

    importance >= 0.3 or emotional_impact != "neutral"
  end

  defp add_temporal_context(memory) do
    now = DateTime.utc_now()

    memory
    |> Map.put(:created_at, now)
    |> Map.put(:time_of_day, extract_time_of_day(now))
    |> Map.put(:recency_weight, 1.0)  # Will decay over time
  end

  defp generate_embedding_text(memory) do
    # Create text representation for vector embedding
    embedding_text = [
      memory.description,
      "Type: #{memory.type}",
      "Tags: #{Enum.join(memory.tags, ", ")}",
      "Context: #{memory.context}",
      "PAC: #{memory.pac_name}"
    ]
    |> Enum.join(" | ")

    Map.put(memory, :embedding_text, embedding_text)
  end

  # Memory Storage

  defp store_memories(memories, pac_id) do
    stored_memories =
      memories
      |> Enum.map(&store_single_memory(&1, pac_id))
      |> Enum.filter(fn
        {:ok, _} -> true
        {:error, _} -> false
      end)
      |> Enum.map(fn {:ok, memory} -> memory end)

    # Update memory statistics
    if length(stored_memories) > 0 do
      MemoryManager.update_memory_stats(pac_id, length(stored_memories))
    end

    {:ok, stored_memories}
  end

  defp store_single_memory(memory, pac_id) do
    case MemoryManager.store_memory(pac_id, memory) do
      {:ok, stored_memory} ->
        # Generate and store vector embedding
        case VectorSearch.generate_embedding(memory.embedding_text) do
          {:ok, embedding} ->
            VectorSearch.store_embedding(stored_memory.id, embedding)
            {:ok, stored_memory}

          {:error, reason} ->
            Logger.warn("Failed to generate embedding for memory: #{inspect(reason)}")
            {:ok, stored_memory}  # Store memory even if embedding fails
        end

      {:error, reason} ->
        Logger.error("Failed to store memory: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Utility Functions

  defp extract_context_summary(context) do
    zone_name = context.zone_context["name"] || "unknown zone"
    pac_count = context.zone_context["pac_count"] || 0

    "In #{zone_name} with #{pac_count} other PACs present"
  end

  defp calculate_action_importance(experience) do
    base_importance = 0.5

    # Increase importance for successful actions
    success_bonus = if experience.success, do: 0.2, else: 0.0

    # Increase importance for high-energy actions
    energy_bonus = case experience.execution_result[:energy_cost] do
      cost when cost > 20 -> 0.3
      cost when cost > 10 -> 0.1
      _ -> 0.0
    end

    # Increase importance for creative/learning actions
    type_bonus = case experience.execution_result[:type] do
      :creation -> 0.4
      :learning -> 0.3
      :social_interaction -> 0.2
      :exploration -> 0.2
      _ -> 0.0
    end

    min(1.0, base_importance + success_bonus + energy_bonus + type_bonus)
  end

  defp calculate_social_importance(experience, context) do
    base = 0.6

    # Higher importance if many PACs were present
    social_bonus = case context.zone_context["pac_count"] do
      count when count > 5 -> 0.3
      count when count > 2 -> 0.2
      count when count > 0 -> 0.1
      _ -> 0.0
    end

    base + social_bonus
  end

  defp calculate_emotional_valence(experience) do
    case {experience.success, experience.execution_result[:mood_effect]} do
      {true, "fulfilled"} -> 0.9
      {true, "satisfied"} -> 0.7
      {true, "social"} -> 0.6
      {true, "adventurous"} -> 0.5
      {true, _} -> 0.3
      {false, _} -> -0.5
    end
  end

  defp calculate_social_valence(experience) do
    case experience.execution_result[:interaction_type] do
      "positive_conversation" -> 0.8
      "casual_conversation" -> 0.5
      "collaboration" -> 0.7
      "conflict" -> -0.3
      _ -> 0.3
    end
  end

  defp adjust_importance_for_personality(memory, personality) do
    multiplier = case {memory.type, personality.decision_tendency} do
      {:learning, "analytical"} -> 1.3
      {:creative, "innovative"} -> 1.4
      {:social, tendency} when tendency in ["collaborative", "social"] -> 1.2
      {:discovery, "exploratory"} -> 1.3
      _ -> 1.0
    end

    updated_importance = min(1.0, memory.importance * multiplier)
    Map.put(memory, :importance, updated_importance)
  end

  defp generate_action_tags(experience) do
    base_tags = [experience.action]

    type_tags = case experience.execution_result[:type] do
      :tool_success -> ["tool_use", experience.execution_result[:tool]]
      :rest -> ["maintenance", "energy"]
      :reflection -> ["introspection", "growth"]
      :social_interaction -> ["social", "communication"]
      :exploration -> ["discovery", "movement"]
      :creation -> ["creative", "achievement"]
      :learning -> ["education", "skill_development"]
      :goal_progress -> ["achievement", "progress"]
      _ -> []
    end

    success_tags = if experience.success, do: ["success"], else: ["failure"]

    (base_tags ++ type_tags ++ success_tags)
    |> Enum.uniq()
  end

  defp extract_time_of_day(datetime) do
    hour = datetime.hour

    cond do
      hour < 6 -> "night"
      hour < 12 -> "morning"
      hour < 18 -> "afternoon"
      true -> "evening"
    end
  end

  defp extract_memory_types(memories) do
    memories
    |> Enum.map(& &1.type)
    |> Enum.frequencies()
  end

  defp extract_significant_events(memories) do
    memories
    |> Enum.filter(&(&1.importance > 0.7))
    |> Enum.map(&(&1.description))
  end

  defp calculate_emotional_impact(memories) do
    if length(memories) > 0 do
      total_valence =
        memories
        |> Enum.map(&(&1.emotional_valence))
        |> Enum.sum()

      total_valence / length(memories)
    else
      0.0
    end
  end
end
