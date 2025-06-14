defmodule Thunderline.AgentCore.ContextAssessor do
  @moduledoc """
  Extracts and summarizes PAC state, zone context, memories, and modifiers.
  Performs detailed context assessment based on agent state, environment, and history.
  """

  require Logger
  alias Thunderline.PAC.Agent

  # Types might need to be more specific based on actual Agent struct, etc.
  @type agent :: Agent.t() | map() # Assuming Agent.t() or a map representation
  @type zone_context :: map()
  @type memories :: list(map())
  @type tools :: list(String.t())
  @type tick_count :: integer()
  @type federation_context :: map()
  @type context_map :: map()
  @type metadata :: map()

  @spec run(agent(), zone_context(), memories(), tools(), tick_count(), federation_context()) :: {:ok, {context_map(), metadata()}} | {:error, any()}
  def run(agent, zone_context, memories, tools, tick_count, federation_context) do
    with {:ok, situation_analysis} <- analyze_situation(agent, zone_context),
         {:ok, needs_assessment} <- assess_needs(agent, tick_count),
         {:ok, memory_relevance} <- evaluate_memories(memories, agent),
         {:ok, capability_map} <- map_capabilities(tools, agent) do

      assessment = %{
        situation: situation_analysis,
        needs: needs_assessment,
        relevant_memories: memory_relevance,
        capabilities: capability_map,
        context_summary: build_context_summary(agent, zone_context, memories),
        timestamp: DateTime.utc_now(),
        federation_context: federation_context
      }

      Logger.debug("Context assessment complete for PAC Agent #{agent.name}")
      {:ok, {assessment, %{timestamp: DateTime.utc_now(), source: :internal_assessor}}}
    else
      {:error, reason} ->
        Logger.error("Context assessment failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Analysis Functions

  defp analyze_situation(agent, zone_context) do
    situation = %{
      energy_level: categorize_energy(agent.stats["energy"]),
      mood_state: agent.state["mood"],
      current_activity: agent.state["activity"],
      zone_type: zone_context["zone_type"],
      zone_rules: zone_context["rules"] || %{},
      social_context: analyze_social_context(zone_context)
    }

    {:ok, situation}
  end

  defp assess_needs(agent, tick_count) do
    stats = agent.stats
    state = agent.state

    needs = %{
      primary_needs: identify_primary_needs(stats, state),
      goal_progress: evaluate_goal_progress(state["goals"] || []),
      social_needs: assess_social_needs(stats["social"], tick_count),
      learning_needs: assess_learning_needs(stats["curiosity"], stats["intelligence"]),
      creative_needs: assess_creative_needs(stats["creativity"], state["activity"])
    }

    {:ok, needs}
  end

  defp evaluate_memories(memories, agent) do
    # Score memories by relevance to current situation
    scored_memories =
      memories
      |> Enum.map(&score_memory_relevance(&1, agent))
      |> Enum.sort_by(& &1.relevance_score, :desc)
      |> Enum.take(5)  # Keep top 5 most relevant

    {:ok, scored_memories}
  end

  defp map_capabilities(available_tools, agent) do
    # Map available tools to PAC Agent's traits and goals
    capabilities = %{
      tools: available_tools,
      applicable_tools: filter_applicable_tools(available_tools, agent),
      tool_experience: get_tool_experience(agent),
      preferred_tools: infer_preferred_tools(agent.traits, agent.stats)
    }

    {:ok, capabilities}
  end

  # Helper Functions

  defp categorize_energy(energy) when is_integer(energy) and energy > 80, do: "high"
  defp categorize_energy(energy) when is_integer(energy) and energy > 50, do: "medium"
  defp categorize_energy(energy) when is_integer(energy) and energy > 20, do: "low"
  defp categorize_energy(_), do: "depleted"

  defp analyze_social_context(zone_context) do
    %{
      other_agents_present: zone_context["pac_count"] || 0,
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

  defp evaluate_goal_progress(goals) when is_list(goals) do
    Enum.map(goals, fn goal ->
      %{
        goal: goal["description"] || goal,
        progress: goal["progress"] || 0,
        urgency: goal["urgency"] || "medium",
        blockers: goal["blockers"] || []
      }
    end)
  end
  defp evaluate_goal_progress(_), do: []


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

  defp score_memory_relevance(memory, agent) do
    base_score = 0.5

    # Increase score based on recency
    recency_score = calculate_recency_score(memory["timestamp"])

    # Increase score based on emotional significance
    emotion_score = calculate_emotion_score(memory["emotion"], agent.state["mood"])

    # Increase score based on topic relevance
    topic_score = calculate_topic_relevance(memory["tags"], agent.state["activity"])

    total_score = base_score + recency_score + emotion_score + topic_score

    Map.put(memory, :relevance_score, total_score)
  end

  defp filter_applicable_tools(tools, agent) do
    # Filter tools based on PAC Agent's traits and current situation
    Enum.filter(tools, fn tool ->
      is_tool_applicable?(tool, agent.traits, agent.stats, agent.state)
    end)
  end

  defp get_tool_experience(agent) do
    # Extract tool usage history from PAC Agent state or memories
    agent.state["tool_experience"] || %{}
  end

  defp infer_preferred_tools(traits, stats) do
    preferences = []

    preferences = if Enum.member?(traits, "analytical") or stats["intelligence"] > 70 do
      ["analysis_tools", "data_tools" | preferences]
    else
      preferences
    end

    preferences = if Enum.member?(traits, "creative") or stats["creativity"] > 70 do
      ["creative_tools", "generation_tools" | preferences]
    else
      preferences
    end

    preferences = if Enum.member?(traits, "social") or stats["social"] > 70 do
      ["communication_tools", "collaboration_tools" | preferences]
    else
      preferences
    end

    preferences
  end

  defp build_context_summary(agent, zone_context, memories) do
    """
    PAC Agent #{agent.name} is currently #{agent.state["activity"]} in #{zone_context["name"] || "an unknown zone"}.
    Energy level: #{agent.stats["energy"]}/100
    Mood: #{agent.state["mood"]}
    Recent relevant experiences: #{length(memories)} memories available.
    Current goals: #{length(agent.state["goals"] || [])} active goals.
    """
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
    if Enum.member?(memory_tags, current_activity), do: 0.3, else: 0.0
  end
  defp calculate_topic_relevance(_, _), do: 0.0

  defp calculate_isolation_duration(tick_count) when is_integer(tick_count) do
    # Estimate isolation based on tick count (simplified)
    max(0, tick_count - 10)
  end
  defp calculate_isolation_duration(_), do: 0


  defp is_tool_applicable?(tool, traits, stats, state) when is_list(traits) and is_map(stats) and is_map(state) do
    # Simple applicability check based on tool and agent characteristics
    case tool do
      "communication" -> Enum.member?(traits, "social") or stats["social"] > 50
      "analysis" -> Enum.member?(traits, "analytical") or stats["intelligence"] > 60
      "creative" -> Enum.member?(traits, "creative") or stats["creativity"] > 60
      _ -> true  # Default tools are always applicable
    end
  end
  defp is_tool_applicable?(_, _, _, _), do: true # Fallback for mismatched types
end
