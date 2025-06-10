defmodule Thunderline.Agents.Actions.AssessContext do
  @moduledoc """
  Action for assessing PAC context and situation.

  This action evaluates:
  - Current PAC state and needs
  - Environmental factors and zone context
  - Relevant memories and past experiences
  - Available tools and capabilities
  - Social context and nearby PACs
  """

  use Jido.Action,
    name: "assess_context",
    description: "Assess current context and situation for decision making",
    schema: [
      pac: [type: :map, required: true],
      zone_context: [type: :map, default: %{}],
      memories: [type: {:list, :map}, default: []],
      available_tools: [type: {:list, :string}, default: []],
      tick_count: [type: :integer, default: 0]
    ]

  require Logger
  alias Thunderline.{PAC, Memory}
  alias Thunderline.PAC.Zone
  alias Thunderline.Memory.Manager, as: MemoryManager
  alias Thunderline.MCP.{ToolRegistry, PromptManager}
  alias Thunderline.Agents.AIProvider
    @impl true
  def run(params, context) do
    %{
      pac: pac,
      zone_context: zone_context,
      memories: memories,
      available_tools: tools,
      tick_count: tick_count
    } = params

    Logger.debug("Assessing context for PAC #{pac["name"]}")

    # Build context for AI assessment
    assessment_context = %{
      pac_name: pac["name"],
      traits: pac["traits"] || [],
      stats: pac["stats"] || %{},
      current_state: pac["state"] || %{},
      environment_context: zone_context,
      memories: memories,
      available_tools: tools,
      tick_count: tick_count
    }

    # Generate AI assessment
    prompt = PromptManager.generate_context_prompt(assessment_context)

    case AIProvider.reason(prompt, assessment_context) do
      {:ok, ai_assessment} ->
        # Combine AI assessment with additional analysis
        with {:ok, needs_assessment} <- assess_needs(pac, tick_count),
             {:ok, memory_relevance} <- evaluate_memories(memories, pac),
             {:ok, capability_map} <- map_capabilities(tools, pac) do

          assessment = %{
            ai_assessment: ai_assessment,
            needs: needs_assessment,
            memory_relevance: memory_relevance,
            capabilities: capability_map,
            context_summary: generate_context_summary(ai_assessment, pac),
            timestamp: DateTime.utc_now(),
            pac_name: pac["name"],
            stats: pac["stats"],
            traits: pac["traits"],
            goals: Map.get(pac["state"], "goals", [])
          }

          Logger.debug("Context assessment completed for #{pac["name"]}")
          {:ok, assessment}
        end

      {:error, reason} ->
        Logger.warning("AI assessment failed for #{pac["name"]}: #{inspect(reason)}")
        # Fall back to rule-based assessment
        fallback_assessment(pac, zone_context, memories, tools, tick_count)
    end
  end

  defp fallback_assessment(pac, zone_context, memories, tools, tick_count) do
    with {:ok, situation_analysis} <- analyze_situation(pac, zone_context),
         {:ok, needs_assessment} <- assess_needs(pac, tick_count),
         {:ok, memory_relevance} <- evaluate_memories(memories, pac),
         {:ok, capability_map} <- map_capabilities(tools, pac) do

      assessment = %{
        situation: situation_analysis,
        needs: needs_assessment,
        relevant_memories: memory_relevance,
        capabilities: capability_map,
        context_summary: build_context_summary(pac, zone_context, memories),
        timestamp: DateTime.utc_now()
      }

      Logger.debug("Context assessment complete for PAC #{pac["name"]}")
      {:ok, assessment}
    else
      {:error, reason} ->
        Logger.error("Context assessment failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Analysis Functions

  defp analyze_situation(pac, zone_context) do
    situation = %{
      energy_level: categorize_energy(pac["stats"]["energy"]),
      mood_state: pac["state"]["mood"],
      current_activity: pac["state"]["activity"],
      zone_type: zone_context["zone_type"],
      zone_rules: zone_context["rules"] || %{},
      social_context: analyze_social_context(zone_context)
    }

    {:ok, situation}
  end

  defp assess_needs(pac, tick_count) do
    stats = pac["stats"]
    state = pac["state"]

    needs = %{
      primary_needs: identify_primary_needs(stats, state),
      goal_progress: evaluate_goal_progress(state["goals"] || []),
      social_needs: assess_social_needs(stats["social"], tick_count),
      learning_needs: assess_learning_needs(stats["curiosity"], stats["intelligence"]),
      creative_needs: assess_creative_needs(stats["creativity"], state["activity"])
    }

    {:ok, needs}
  end

  defp evaluate_memories(memories, pac) do
    # Score memories by relevance to current situation
    scored_memories =
      memories
      |> Enum.map(&score_memory_relevance(&1, pac))
      |> Enum.sort_by(& &1.relevance_score, :desc)
      |> Enum.take(5)  # Keep top 5 most relevant

    {:ok, scored_memories}
  end

  defp map_capabilities(available_tools, pac) do
    # Map available tools to PAC's traits and goals
    capabilities = %{
      tools: available_tools,
      applicable_tools: filter_applicable_tools(available_tools, pac),
      tool_experience: get_tool_experience(pac),
      preferred_tools: infer_preferred_tools(pac["traits"], pac["stats"])
    }

    {:ok, capabilities}
  end

  # Helper Functions

  defp categorize_energy(energy) when energy > 80, do: "high"
  defp categorize_energy(energy) when energy > 50, do: "medium"
  defp categorize_energy(energy) when energy > 20, do: "low"
  defp categorize_energy(_), do: "depleted"

  defp analyze_social_context(zone_context) do
    %{
      other_pacs_present: zone_context["pac_count"] || 0,
      interaction_opportunities: zone_context["interactions"] || [],
      social_atmosphere: zone_context["atmosphere"] || "neutral"
    }
  end

  defp identify_primary_needs(stats, state) do
    needs = []

    needs = if stats["energy"] < 30, do: ["rest" | needs], else: needs
    needs = if state["mood"] == "bored", do: ["stimulation" | needs], else: needs
    needs = if state["mood"] == "lonely", do: ["social_interaction" | needs], else: needs
    needs = if length(state["goals"] || []) == 0, do: ["purpose" | needs], else: needs

    needs
  end

  defp evaluate_goal_progress(goals) do
    Enum.map(goals, fn goal ->
      %{
        goal: goal["description"] || goal,
        progress: goal["progress"] || 0,
        urgency: goal["urgency"] || "medium",
        blockers: goal["blockers"] || []
      }
    end)
  end

  defp assess_social_needs(social_stat, tick_count) do
    %{
      social_energy: social_stat,
      isolation_duration: calculate_isolation_duration(tick_count),
      interaction_preference: if(social_stat > 60, do: "seeks", else: "neutral")
    }
  end

  defp assess_learning_needs(curiosity, intelligence) do
    %{
      curiosity_level: curiosity,
      learning_capacity: intelligence,
      exploration_drive: if(curiosity > 70, do: "high", else: "moderate"),
      new_skill_interest: curiosity + intelligence > 120
    }
  end

  defp assess_creative_needs(creativity, current_activity) do
    %{
      creative_energy: creativity,
      seeking_expression: creativity > 60 and current_activity != "creating",
      idea_generation_mode: creativity > 80
    }
  end

  defp score_memory_relevance(memory, pac) do
    base_score = 0.5

    # Increase score based on recency
    recency_score = calculate_recency_score(memory["timestamp"])

    # Increase score based on emotional significance
    emotion_score = calculate_emotion_score(memory["emotion"], pac["state"]["mood"])

    # Increase score based on topic relevance
    topic_score = calculate_topic_relevance(memory["tags"], pac["state"]["activity"])

    total_score = base_score + recency_score + emotion_score + topic_score

    Map.put(memory, :relevance_score, total_score)
  end

  defp filter_applicable_tools(tools, pac) do
    # Filter tools based on PAC's traits and current situation
    Enum.filter(tools, fn tool ->
      is_tool_applicable?(tool, pac["traits"], pac["stats"], pac["state"])
    end)
  end

  defp get_tool_experience(pac) do
    # Extract tool usage history from PAC state or memories
    pac["state"]["tool_experience"] || %{}
  end

  defp infer_preferred_tools(traits, stats) do
    preferences = []

    preferences = if "analytical" in traits or stats["intelligence"] > 70 do
      ["analysis_tools", "data_tools" | preferences]
    else
      preferences
    end

    preferences = if "creative" in traits or stats["creativity"] > 70 do
      ["creative_tools", "generation_tools" | preferences]
    else
      preferences
    end

    preferences = if "social" in traits or stats["social"] > 70 do
      ["communication_tools", "collaboration_tools" | preferences]
    else
      preferences
    end

    preferences
  end

  defp build_context_summary(pac, zone_context, memories) do
    """
    PAC #{pac["name"]} is currently #{pac["state"]["activity"]} in #{zone_context["name"] || "an unknown zone"}.
    Energy level: #{pac["stats"]["energy"]}/100
    Mood: #{pac["state"]["mood"]}
    Recent relevant experiences: #{length(memories)} memories available.
    Current goals: #{length(pac["state"]["goals"] || [])} active goals.
    """
  end

  defp generate_context_summary(ai_assessment, pac) do
    emotional_state = Map.get(ai_assessment, "emotional_state", "unknown")
    priorities = Map.get(ai_assessment, "priorities", [])
    priority_list = if is_list(priorities), do: Enum.join(priorities, ", "), else: "none"

    "#{pac["name"]} is feeling #{emotional_state}. Current priorities: #{priority_list}"
  end

  # Utility functions for scoring

  defp calculate_recency_score(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> calculate_recency_score(dt)
      _ -> 0.0
    end
  end

  defp calculate_recency_score(%DateTime{} = timestamp) do
    hours_ago = DateTime.diff(DateTime.utc_now(), timestamp, :hour)
    max(0.0, 0.3 - (hours_ago * 0.01))  # Decay over time
  end

  defp calculate_recency_score(_), do: 0.0

  defp calculate_emotion_score(memory_emotion, current_mood) do
    if memory_emotion == current_mood, do: 0.2, else: 0.0
  end

  defp calculate_topic_relevance(memory_tags, current_activity) when is_list(memory_tags) do
    if current_activity in memory_tags, do: 0.3, else: 0.0
  end
  defp calculate_topic_relevance(_, _), do: 0.0

  defp is_tool_applicable?(tool, traits, stats, state) do
    # Simple heuristic - could be made more sophisticated
    case tool do
      "creative_" <> _ -> "creative" in traits or stats["creativity"] > 60
      "social_" <> _ -> "social" in traits or stats["social"] > 60
      "analysis_" <> _ -> "analytical" in traits or stats["intelligence"] > 60
      _ -> true  # General tools are always applicable
    end
  end

  defp calculate_isolation_duration(tick_count) do
    # Placeholder - would track actual social interactions
    if tick_count > 10, do: "extended", else: "recent"
  end
end
