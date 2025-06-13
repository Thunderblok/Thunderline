defmodule Thunderline.AgentCore.MemoryBuilder do
  @moduledoc """
  Processes tick outcomes (experiences) to form and store significant memories for a PAC Agent.
  Handles memory candidate extraction, enrichment (potentially via AI), filtering, and storage.
  """

  require Logger

  alias Thunderline.Memory.Manager, as: MemoryManager
  alias Thunderline.Memory.VectorSearch
  alias Thunderline.MCP.PromptManager
  alias Thunderline.Agents.AIProvider

  @type experience_map :: map() # Contains action outcome, success, execution_result, etc.
  @type pac_config_map :: map() # %{pac_id: String.t(), pac_name: String.t(), stats: map(), traits: list(String.t()), personality: map()}
  @type tick_context_map :: map() # %{zone_context: map(), ...}
  @type previous_state_map :: map() # Agent's state before the action
  @type memory_report_map :: map() # Contains memories_formed, memory_types, etc.

  @spec store_results(experience_map(), pac_config_map(), tick_context_map(), previous_state_map()) ::
          {:ok, memory_report_map()} | {:error, any()}
  def store_results(experience, pac_config, tick_context, prev_state) do
    pac_id = pac_config.pac_id
    pac_name = pac_config.pac_name

    Logger.debug("MemoryBuilder: Forming memories for PAC #{pac_name} (ID: #{pac_id})")

    with {:ok, memory_candidates} <- extract_memory_candidates(experience, tick_context),
         {:ok, processed_memories} <- process_memories(memory_candidates, pac_config, prev_state),
         {:ok, stored_memories} <- store_memories(processed_memories, pac_id) do

      report = %{
        memories_formed_count: length(stored_memories), # Changed key for clarity
        memory_types: extract_memory_types(stored_memories),
        significant_events_descriptions: extract_significant_events(processed_memories), # Changed key for clarity
        overall_emotional_impact: calculate_emotional_impact(processed_memories), # Changed key
        timestamp: DateTime.utc_now()
      }

      Logger.info("MemoryBuilder: Formed #{length(stored_memories)} memories for PAC #{pac_name}")
      {:ok, report}
    else
      {:error, reason} ->
        Logger.error("MemoryBuilder: Memory formation failed for PAC #{pac_name}: #{inspect(reason)}")
        {:error, reason}
      unexpected_error ->
        Logger.error("MemoryBuilder: Unexpected error for PAC #{pac_name}: #{inspect(unexpected_error)}")
        {:error, {:unexpected_memory_formation_error, unexpected_error}}
    end
  end

  # Memory Extraction (Adapted from Thunderline.Agents.Actions.FormMemory)

  defp extract_memory_candidates(experience, context) do
    candidates = []

    # Extract action-based memories
    action_result = Map.get(experience, :execution_result, %{}) # Robust access

    candidates = if Map.get(experience, :success, false) do # Default to false if :success is nil
      action_memory = create_action_memory(experience, context)
      [action_memory | candidates]
    else
      failure_memory = create_failure_memory(experience, context)
      [failure_memory | candidates]
    end

    # Extract discovery memories
    candidates = if discoveries = action_result[:discoveries], is_list(discoveries) do
      discovery_memories = Enum.map(discoveries, &create_discovery_memory(&1, context))
      discovery_memories ++ candidates
    else
      candidates
    end

    # Extract social interaction memories
    candidates = if action_result[:type] == :social_interaction do
      social_memory = create_social_memory(experience, context) # Pass full experience
      [social_memory | candidates]
    else
      candidates
    end

    # Extract learning memories
    candidates = if learning = action_result[:learning] do
      learning_memory = create_learning_memory(learning, context)
      [learning_memory | candidates]
    else
      candidates
    end

    # Extract creative memories
    candidates = if creation = action_result[:creation] do
      creative_memory = create_creative_memory(creation, context)
      [creative_memory | candidates]
    else
      candidates
    end

    # Ensure all candidates are maps
    valid_candidates = Enum.filter(candidates, &is_map/1)
    {:ok, valid_candidates}
  end

  defp create_action_memory(experience, context) do
    action_result = Map.get(experience, :execution_result, %{})
    %{
      type: :action,
      action: Map.get(experience, :action, "unknown_action"),
      success: Map.get(experience, :success, false),
      description: action_result[:description] || "Performed #{Map.get(experience, :action, "action")}",
      energy_cost: action_result[:energy_cost] || 0,
      mood_effect: action_result[:mood_effect],
      context_summary: extract_context_summary(context), # Changed key from :context
      importance: calculate_action_importance(experience),
      tags: generate_action_tags(experience),
      emotional_valence: calculate_emotional_valence(experience)
    }
  end

  defp create_failure_memory(experience, context) do
    %{
      type: :failure,
      action: Map.get(experience, :action, "unknown_action"),
      error: Map.get(experience, :error, :unknown_error),
      description: "Failed to #{Map.get(experience, :action, "action")}: #{inspect(Map.get(experience, :error, :unknown_error))}",
      context_summary: extract_context_summary(context),
      importance: 0.7,
      tags: ["failure", "learning", Map.get(experience, :action, "action")],
      emotional_valence: -0.6
    }
  end

  defp create_discovery_memory(discovery, context) do
    %{
      type: :discovery,
      content: discovery, # Changed key from :discovery to :content for consistency
      description: "Discovered: #{inspect(discovery)}", # Use inspect for safety
      context_summary: extract_context_summary(context),
      importance: 0.8,
      tags: ["discovery", "exploration", "learning"],
      emotional_valence: 0.7
    }
  end

  defp create_social_memory(experience, context) do
    action_result = Map.get(experience, :execution_result, %{})
    %{
      type: :social,
      interaction_type: action_result[:interaction_type] || "general",
      description: action_result[:description] || "Social interaction occurred.",
      context_summary: extract_context_summary(context),
      importance: calculate_social_importance(experience, context), # Pass full experience
      tags: ["social", "interaction", "communication"],
      emotional_valence: calculate_social_valence(experience) # Pass full experience
    }
  end

  defp create_learning_memory(learning_content, context) do # Changed param name
    %{
      type: :learning,
      content: learning_content, # Changed key from :learning
      description: "Learned: #{inspect(learning_content)}", # Use inspect
      context_summary: extract_context_summary(context),
      importance: 0.8,
      tags: ["learning", "knowledge", "growth"],
      emotional_valence: 0.5
    }
  end

  defp create_creative_memory(creation_content, context) do # Changed param name
    %{
      type: :creative,
      content: creation_content, # Changed key from :creation
      description: "Created: #{inspect(creation_content)}", # Use inspect
      context_summary: extract_context_summary(context),
      importance: 0.9,
      tags: ["creative", "achievement", "expression"],
      emotional_valence: 0.8
    }
  end

  # Memory Processing
  defp process_memories(candidates, pac_config, prev_state) do
    processed =
      candidates
      |> Enum.map(&enrich_memory(&1, pac_config, prev_state)) # Renamed for clarity
      |> Enum.filter(&filter_significant_memories/1)
      |> Enum.map(&add_temporal_context/1)
      |> Enum.map(&generate_embedding_text/1) # This adds :embedding_text field

    {:ok, processed}
  end

  # Combined enrich_memory_with_ai and enrich_memory_fallback
  defp enrich_memory(memory_candidate, pac_config, prev_state) do
    # Prepare base memory fields that are common
    base_memory_data = %{
      pac_id: pac_config.pac_id,
      pac_name: pac_config.pac_name,
      timestamp: DateTime.utc_now(),
      pac_stats_snapshot: pac_config.stats, # Snapshot of current stats
      pac_traits: pac_config.traits,
      state_before: prev_state, # Agent's state before the action
      # Fields from candidate, ensuring they exist
      action: Map.get(memory_candidate, :action),
      success: Map.get(memory_candidate, :success),
      description: Map.get(memory_candidate, :description, "No description"),
      context_summary: Map.get(memory_candidate, :context_summary),
      importance: Map.get(memory_candidate, :importance, 0.5), # Default importance
      tags: Map.get(memory_candidate, :tags, []),
      emotional_valence: Map.get(memory_candidate, :emotional_valence, 0.0),
      type: Map.get(memory_candidate, :type, :general_event), # type from candidate
      content: Map.get(memory_candidate, :content) # For discovery, learning, creative
    }

    # AI Enrichment (optional, can be feature flagged or based on config)
    # For now, let's assume a simpler enrichment if AI is not called, or a direct merge.
    # The original code called AIProvider.reason. Here we simulate a simpler path.
    # prompt = PromptManager.generate_memory_prompt(...)
    # case AIProvider.reason(prompt, ...)
    # For this refactoring, focusing on structure, we'll use the candidate's data primarily.
    # A more complex AI enrichment would merge AI insights into base_memory_data.

    # Example: If AI was to refine description or add insights:
    # ai_insights = %{description: "AI refined: " <> base_memory_data.description, insights: ["AI insight"]}
    # final_memory_data = Map.merge(base_memory_data, ai_insights)

    final_memory_data = base_memory_data # Using base data for now without explicit AI call here

    adjust_importance_for_personality(final_memory_data, pac_config.personality)
  end


  defp filter_significant_memories(memory) do
    importance = Map.get(memory, :importance, 0.0) # Default to 0.0 if nil
    # Assuming emotional_valence is a number, not string "neutral"
    emotional_valence_abs = abs(Map.get(memory, :emotional_valence, 0.0))

    importance >= 0.3 or emotional_valence_abs >= 0.4 # Example thresholds
  end

  defp add_temporal_context(memory) do
    now = Map.get(memory, :timestamp, DateTime.utc_now()) # Use existing timestamp or now
    Map.merge(memory, %{
      created_at_iso: DateTime.to_iso8601(now), # Store ISO string
      time_of_day: extract_time_of_day(now),
      recency_score: 1.0  # Initial recency score, decays elsewhere
    })
  end

  defp generate_embedding_text(memory) do
    # Create text representation for vector embedding
    text_parts = [
      "Description: #{memory.description}",
      "Type: #{Atom.to_string(memory.type)}", # Ensure type is string/atom
      "Tags: #{Enum.join(memory.tags || [], ", ")}",
      "Context: #{memory.context_summary}",
      "Agent: #{memory.pac_name}",
      "Action: #{memory.action || "N/A"}",
      "Success: #{memory.success || "N/A"}",
      "Emotional Valence: #{memory.emotional_valence || 0.0}"
    ]
    embedding_text = Enum.reject(text_parts, &is_nil/1) |> Enum.join(" | ")
    Map.put(memory, :embedding_text, embedding_text)
  end

  defp adjust_importance_for_personality(memory, personality_map) when is_map(personality_map) do
    # Personality might be like %{decision_tendency: "analytical"}
    # This function should ideally use more specific personality traits if available.
    multiplier = case {memory.type, personality_map.decision_tendency} do
      {:learning, "analytical"} -> 1.3
      {:creative, "innovative"} -> 1.4 # Assuming "innovative" is a tendency
      {:social, tendency} when tendency in ["collaborative", "social_oriented"] -> 1.2
      {:discovery, "exploratory"} -> 1.3
      _ -> 1.0
    end
    updated_importance =記憶體min(1.0, (memory.importance || 0.5) * multiplier) # Ensure importance exists
    Map.put(memory, :importance, updated_importance)
  end
  defp adjust_importance_for_personality(memory, _), do: memory # No personality map

  # Memory Storage

  defp store_memories(memories_to_store, pac_id) when is_list(memories_to_store) do
    {successes, failures} =
      memories_to_store
      |> Enum.map(&store_single_memory(&1, pac_id))
      |> Enum.split_with(fn {:ok, _} -> true; _ -> false end)

    stored_memories = Enum.map(successes, fn {:ok, mem} -> mem end)

    if !Enum.empty?(failures) do
      Logger.error("MemoryBuilder: Failed to store #{length(failures)} memories for PAC ID #{pac_id}.")
    end

    # Update memory statistics (optional, if MemoryManager provides it)
    # if length(stored_memories) > 0 do
    #   MemoryManager.update_memory_stats(pac_id, length(stored_memories))
    # end

    {:ok, stored_memories}
  end
  defp store_memories(_, _), do: {:ok, []} # Not a list or other issue


  defp store_single_memory(memory_data, pac_id) do
    # Ensure memory_data is a map; it should be by this point.
    # MemoryManager.store_memory might expect certain fields or structure.
    # The memory_data here is what `enrich_memory` produces.

    # The original code used MemoryManager.store_memory(pac_id, memory)
    # This implies the pac_id might not be needed directly in the memory map for storage,
    # or it's used by the manager to associate. Let's assume it's not part of the map itself.
    memory_to_create = Map.put(memory_data, :pac_id, pac_id) # Ensure pac_id is in the map for creation

    case MemoryManager.create_memory(memory_to_create) do # Changed from store_memory to create_memory
      {:ok, stored_memory_struct} ->
        # Generate and store vector embedding
        embedding_text = Map.get(stored_memory_struct, :embedding_text, Map.get(memory_data, :embedding_text, ""))

        if String.trim(embedding_text) != "" do
          case VectorSearch.add_embedding(pac_id, stored_memory_struct.id, embedding_text) do
            {:ok, _embedding_result} -> :ok
            {:error, reason} -> Logger.warn("MemoryBuilder: Failed to generate/store embedding for memory #{stored_memory_struct.id}: #{inspect(reason)}")
          end
        else
          Logger.warn("MemoryBuilder: Embedding text is empty for memory #{stored_memory_struct.id}. Skipping embedding.")
        end
        {:ok, stored_memory_struct}

      {:error, reason} ->
        Logger.error("MemoryBuilder: Failed to store memory for PAC #{pac_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Utility Functions (Adapted from Thunderline.Agents.Actions.FormMemory)

  defp extract_context_summary(context) when is_map(context) do
    zone_ctx = Map.get(context, :zone_context, %{})
    zone_name = Map.get(zone_ctx, "name", "an unknown zone")
    pac_count = Map.get(zone_ctx, "pac_count", 0)
    "In #{zone_name} with #{pac_count} other PACs present." # Original logic had 'other PACs'
  end
  defp extract_context_summary(_), do: "In an undefined context."


  defp calculate_action_importance(experience) when is_map(experience) do
    base_importance = 0.5
    action_result = Map.get(experience, :execution_result, %{})

    success_bonus = if Map.get(experience, :success, false), do: 0.2, else: 0.0
    energy_bonus = case action_result[:energy_cost] do
      cost when is_number(cost) and cost > 20 -> 0.3
      cost when is_number(cost) and cost > 10 -> 0.1
      _ -> 0.0
    end
    type_bonus = case action_result[:type] do
      :creation -> 0.4
      :learning -> 0.3
      :social_interaction -> 0.2
      :exploration -> 0.2
      _ -> 0.0
    end
    min(1.0, base_importance + success_bonus + energy_bonus + type_bonus)
  end
  defp calculate_action_importance(_), do: 0.5


  defp calculate_social_importance(experience, context) when is_map(experience) and is_map(context) do
    base = 0.6
    zone_ctx = Map.get(context, :zone_context, %{})
    social_bonus = case Map.get(zone_ctx, "pac_count", 0) do
      count when count > 5 -> 0.3
      count when count > 2 -> 0.2
      count when count > 0 -> 0.1 # Assuming pac_count is total, so > 1 means others
      _ -> 0.0
    end
    min(1.0, base + social_bonus)
  end
  defp calculate_social_importance(_, _), do: 0.6

  defp calculate_emotional_valence(experience) when is_map(experience) do
    action_result = Map.get(experience, :execution_result, %{})
    case {Map.get(experience, :success), action_result[:mood_effect]} do
      {true, "fulfilled"} -> 0.9
      {true, "satisfied"} -> 0.7
      {true, "social"} -> 0.6
      {true, "adventurous"} -> 0.5
      {true, _} -> 0.3
      {false, _} -> -0.5
      _ -> 0.0 # Default if success is nil
    end
  end
  defp calculate_emotional_valence(_), do: 0.0

  defp calculate_social_valence(experience) when is_map(experience) do
    action_result = Map.get(experience, :execution_result, %{})
    case action_result[:interaction_type] do
      "positive_conversation" -> 0.8
      "casual_conversation" -> 0.5
      "collaboration" -> 0.7
      "conflict" -> -0.3
      _ -> 0.3
    end
  end
  defp calculate_social_valence(_), do: 0.3


  defp generate_action_tags(experience) when is_map(experience) do
    action_result = Map.get(experience, :execution_result, %{})
    base_tags = [Map.get(experience, :action, "unknown")]

    type_tags = case action_result[:type] do
      :tool_success -> ["tool_use", Map.get(action_result, :tool_used, "unknown_tool")] # Assuming :tool_used key
      :rest -> ["maintenance", "energy"]
      :reflection -> ["introspection", "growth"]
      :social_interaction -> ["social", "communication"]
      :exploration -> ["discovery", "movement"]
      :creation -> ["creative", "achievement"]
      :learning -> ["education", "skill_development"]
      :goal_progress -> ["achievement", "progress"]
      _ -> []
    end
    success_tags = if Map.get(experience, :success, false), do: ["success"], else: ["failure"]
    Enum.uniq(base_tags ++ type_tags ++ success_tags)
  end
  defp generate_action_tags(_), do: ["unknown_action_event"]


  defp extract_time_of_day(%DateTime{} = datetime), do: DateTime.to_time(datetime) |> Time.to_string() |> String.slice(0..1) |> then(&Kernel.<>(&1, "h")) # Simplified: "03h", "14h"
  defp extract_time_of_day(_), do: "unknown_time"


  defp extract_memory_types(memories) when is_list(memories) do
    memories |> Enum.map(&Map.get(&1, :type, :unknown)) |> Enum.frequencies()
  end
  defp extract_memory_types(_), do: %{}

  defp extract_significant_events(memories) when is_list(memories) do
    memories
    |> Enum.filter(&(Map.get(&1, :importance, 0.0) > 0.7))
    |> Enum.map(&Map.get(&1, :description, "No description."))
  end
  defp extract_significant_events(_), do: []

  defp calculate_emotional_impact(memories) when is_list(memories) and memories != [] do
    {sum_valence, count} =
      memories
      |> Enum.reduce({0.0, 0}, fn memory, {current_sum, current_count} ->
        valence = Map.get(memory, :emotional_valence, 0.0)
        {current_sum + valence, current_count + 1}
      end)
    if count > 0, do: sum_valence / count, else: 0.0
  end
  defp calculate_emotional_impact(_), do: 0.0
end
