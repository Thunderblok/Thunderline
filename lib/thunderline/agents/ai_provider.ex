defmodule Thunderline.Agents.AIProvider do
  @moduledoc """
  AI provider for PAC Agent reasoning with federation support.

  This module provides AI reasoning for PAC Agents using:
  - Rule-based decision making (current implementation)
  - OpenAI API integration (configurable)
  - Anthropic Claude integration (configurable)
  - Local LLM via Ollama (configurable)
  - Federation-aware prompt adaptation

  In production systems, this integrates with external AI services
  while maintaining federation context and node-specific customization.
  """

  require Logger

  @doc """
  Generate AI reasoning response for a given prompt and context.
  Supports federation-aware reasoning with node context.
  """
  @spec reason(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def reason(prompt, context) do
    # Add federation context to reasoning
    enhanced_context = add_federation_context(context)

    case get_ai_provider() do
      :openai -> reason_with_openai(prompt, enhanced_context)
      :anthropic -> reason_with_anthropic(prompt, enhanced_context)
      :ollama -> reason_with_ollama(prompt, enhanced_context)
      :rule_based -> reason_with_rules(prompt, enhanced_context)
    end
  end

  @doc """
  Generate a context assessment using AI or rule-based logic.
  """
  def generate_context_assessment(context) do
    agent_name = Map.get(context, :agent_name, "Unknown")
    stats = Map.get(context, :stats, %{})
    traits = Map.get(context, :traits, [])
    environment = Map.get(context, :environment_context, %{})
    federation = Map.get(context, :federation_context, %{})

    observations = build_observations(stats, traits, environment, federation)
    emotional_state = infer_emotional_state(stats, traits)
    opportunities = identify_opportunities(environment, stats, federation)
    threats = identify_threats(environment, stats, federation)
    resources = assess_resources(stats, context)
    priorities = determine_priorities(stats, traits, federation)

    assessment = %{
      "observations" => observations,
      "emotional_state" => emotional_state,
      "opportunities" => opportunities,
      "threats" => threats,
      "resources" => resources,
      "priorities" => priorities,
      "federation_context" => federation
    }

    Logger.debug("Generated context assessment for #{agent_name}")
    {:ok, assessment}
  end

  @doc """
  Generate a decision using AI or rule-based logic with federation awareness.
  """
  def generate_decision(context) do
    available_actions = Map.get(context, :available_actions, [])
    assessment = Map.get(context, :assessment, %{})
    goals = Map.get(context, :goals, [])
    stats = Map.get(context, :stats, %{})
    traits = Map.get(context, :traits, [])
    federation = Map.get(context, :federation_context, %{})

    # Score actions with federation context
    scored_actions = score_actions_with_federation(
      available_actions, assessment, goals, stats, traits, federation
    )

    chosen_action = select_best_action(scored_actions)

    decision = %{
      "chosen_action" => chosen_action.name,
      "reasoning" => chosen_action.reasoning,
      "expected_outcome" => chosen_action.expected_outcome,
      "confidence" => chosen_action.confidence,
      "backup_plan" => select_backup_action(scored_actions, chosen_action),
      "federation_metadata" => %{
        "node_specific_factors" => federation,
        "cross_node_considerations" => assess_cross_node_impact(chosen_action, federation)
      }
    }

    Logger.debug("Generated federation-aware decision: #{chosen_action.name}")
    {:ok, decision}
  end

  @doc """
  Generate a memory using AI or rule-based logic with federation metadata.
  """
  def generate_memory(context) do
    action = Map.get(context, :action, "unknown_action")
    result = Map.get(context, :result, %{})
    traits = Map.get(context, :traits, [])
    federation = Map.get(context, :federation_context, %{})

    memory_type = classify_memory_type(action, result)
    emotional_impact = assess_emotional_impact(result, traits)
    insights = extract_insights(action, result, traits, federation)
    importance = calculate_importance(result, memory_type)
    federation_relevance = assess_federation_relevance(action, result, federation)

    memory = %{
      "type" => memory_type,
      "content" => build_memory_content(action, result, insights),
      "emotional_impact" => emotional_impact,
      "importance" => importance,
      "insights" => insights,
      "federation_metadata" => %{
        "node_id" => Map.get(federation, :node_id),
        "cross_node_relevance" => federation_relevance,
        "sharing_eligibility" => determine_sharing_eligibility(memory_type, importance)
      }
    }

    Logger.debug("Generated federation-aware memory: #{memory_type}")
    {:ok, memory}
  end

  # AI Provider Selection

  defp get_ai_provider do
    Application.get_env(:thunderline, :ai_provider, :rule_based)
  end

  # OpenAI Integration

  defp reason_with_openai(prompt, context) do
    # TODO: Implement OpenAI API integration
    Logger.info("OpenAI reasoning requested - falling back to rule-based")
    reason_with_rules(prompt, context)
  end

  # Anthropic Integration

  defp reason_with_anthropic(prompt, context) do
    # TODO: Implement Anthropic Claude integration
    Logger.info("Anthropic reasoning requested - falling back to rule-based")
    reason_with_rules(prompt, context)
  end

  # Ollama Integration

  defp reason_with_ollama(prompt, context) do
    # TODO: Implement Ollama local LLM integration
    Logger.info("Ollama reasoning requested - falling back to rule-based")
    reason_with_rules(prompt, context)
  end

  # Rule-based Implementation

  defp reason_with_rules(prompt, context) do
    case extract_reasoning_type(prompt) do
      :context_assessment -> generate_context_assessment(context)
      :decision_making -> generate_decision(context)
      :memory_formation -> generate_memory(context)
      _ -> generate_generic_response(context)
    end
  end

  defp extract_reasoning_type(prompt) do
    cond do
      String.contains?(prompt, "assess") -> :context_assessment
      String.contains?(prompt, "decide") -> :decision_making
      String.contains?(prompt, "remember") -> :memory_formation
      true -> :generic
    end
  end

  # Federation Context Enhancement

  defp add_federation_context(context) do
    federation_context = %{
      node_id: Application.get_env(:thunderline, :node_id, "default_node"),
      node_capabilities: Application.get_env(:thunderline, :node_capabilities, []),
      federation_enabled: Application.get_env(:thunderline, :federation_enabled, false),
      peer_nodes: get_peer_nodes(),
      node_load: get_node_load()
    }

    Map.put(context, :federation_context, federation_context)
  end

  defp get_peer_nodes do
    # TODO: Implement actual peer node discovery
    []
  end

  defp get_node_load do
    # TODO: Implement actual node load metrics
    %{cpu: 0.3, memory: 0.4, active_agents: 10}
  end

  # Federation-aware Helper Functions

  defp build_observations(stats, traits, environment, federation) do
    base_observations = build_base_observations(stats, traits, environment)
    federation_observations = build_federation_observations(federation)

    base_observations ++ federation_observations
  end

  defp build_base_observations(stats, traits, environment) do
    observations = []

    # Energy observations
    observations = case stats["energy"] do
      energy when energy > 80 -> ["I feel energetic and ready for action" | observations]
      energy when energy > 50 -> ["I have moderate energy levels" | observations]
      energy when energy > 20 -> ["I'm feeling a bit tired" | observations]
      _ -> ["I'm exhausted and need rest" | observations]
    end

    # Trait-based observations
    observations = if "curious" in traits do
      ["I'm eager to explore and learn new things" | observations]
    else
      observations
    end

    # Environment observations
    observations = case Map.get(environment, :zone_pacs, []) do
      [] -> ["I'm alone in this space" | observations]
      others when length(others) > 0 ->
        ["There are #{length(others)} other agents here" | observations]
    end

    observations
  end

  defp build_federation_observations(federation) do
    observations = []

    if Map.get(federation, :federation_enabled, false) do
      peer_count = length(Map.get(federation, :peer_nodes, []))
      node_load = Map.get(federation, :node_load, %{})

      observations = ["I'm part of a federated network" | observations]

      observations = if peer_count > 0 do
        ["I can interact with #{peer_count} other supervisor nodes" | observations]
      else
        observations
      end

      observations = case Map.get(node_load, :active_agents, 0) do
        count when count > 50 -> ["This node is quite busy with many agents" | observations]
        count when count > 10 -> ["This node has moderate activity" | observations]
        _ -> ["This node is relatively quiet" | observations]
      end

      observations
    else
      ["I'm operating on a standalone node" | observations]
    end
  end

  defp identify_opportunities(environment, stats, federation) do
    opportunities = []

    # Social opportunities
    opportunities = case Map.get(environment, :zone_pacs, []) do
      [] -> opportunities
      others -> ["Collaborate with #{length(others)} other agents" | opportunities]
    end

    # Stat-based opportunities
    opportunities = if stats["creativity"] > 70 do
      ["Express creativity through innovative actions" | opportunities]
    else
      opportunities
    end

    # Federation opportunities
    opportunities = if Map.get(federation, :federation_enabled, false) do
      peer_count = length(Map.get(federation, :peer_nodes, []))
      if peer_count > 0 do
        ["Explore other supervisor nodes and their unique capabilities" | opportunities]
      else
        opportunities
      end
    else
      opportunities
    end

    opportunities
  end

  defp identify_threats(environment, stats, federation) do
    threats = []

    # Energy-based threats
    threats = if stats["energy"] < 20 do
      ["Risk of exhaustion if I don't rest soon" | threats]
    else
      threats
    end

    # Federation threats
    threats = if Map.get(federation, :federation_enabled, false) do
      node_load = Map.get(federation, :node_load, %{})
      if Map.get(node_load, :cpu, 0) > 0.9 do
        ["High node load may affect my performance" | threats]
      else
        threats
      end
    else
      threats
    end

    threats
  end

  defp assess_resources(stats, context) do
    resources = %{
      "energy" => stats["energy"] || 0,
      "intelligence" => stats["intelligence"] || 0,
      "creativity" => stats["creativity"] || 0,
      "social" => stats["social"] || 0
    }

    # Add tool resources
    tools = Map.get(context, :available_tools, [])
    Map.put(resources, "available_tools", length(tools))
  end

  defp determine_priorities(stats, traits, federation) do
    priorities = []

    # Energy priority
    priorities = if stats["energy"] < 30 do
      ["Restore energy through rest" | priorities]
    else
      priorities
    end

    # Trait-based priorities
    priorities = if "social" in traits and Map.get(federation, :federation_enabled, false) do
      ["Connect and collaborate across the federation" | priorities]
    else
      priorities
    end

    # Default priorities
    if Enum.empty?(priorities) do
      ["Explore available actions", "Learn and grow", "Maintain well-being"]
    else
      priorities
    end
  end

  # Action Scoring with Federation

  defp score_actions_with_federation(actions, assessment, goals, stats, traits, federation) do
    Enum.map(actions, fn action ->
      base_score = score_action_base(action, assessment, goals, stats, traits)
      federation_modifier = score_federation_impact(action, federation)

      total_score = base_score * federation_modifier

      %{
        name: action,
        score: total_score,
        reasoning: build_action_reasoning(action, base_score, federation_modifier, federation),
        expected_outcome: predict_outcome(action, stats, federation),
        confidence: calculate_confidence(total_score, stats)
      }
    end)
  end

  defp score_action_base(action, _assessment, _goals, stats, traits) do
    case action do
      "rest" ->
        energy_factor = (100 - stats["energy"]) / 100.0
        0.5 + (energy_factor * 0.4)

      "think" ->
        intelligence_factor = stats["intelligence"] / 100.0
        0.4 + (intelligence_factor * 0.3)

      "explore" ->
        curiosity_factor = stats["curiosity"] / 100.0
        energy_factor = stats["energy"] / 100.0
        0.3 + (curiosity_factor * 0.4) + (energy_factor * 0.2)

      "interact" ->
        social_factor = stats["social"] / 100.0
        social_trait_bonus = if "social" in traits, do: 0.2, else: 0.0
        0.3 + (social_factor * 0.4) + social_trait_bonus

      "create" ->
        creativity_factor = stats["creativity"] / 100.0
        creative_trait_bonus = if "creative" in traits, do: 0.2, else: 0.0
        0.2 + (creativity_factor * 0.5) + creative_trait_bonus

      _ -> 0.3 # Default score for unknown actions
    end
  end

  defp score_federation_impact(action, federation) do
    if Map.get(federation, :federation_enabled, false) do
      peer_count = length(Map.get(federation, :peer_nodes, []))
      node_capabilities = Map.get(federation, :node_capabilities, [])

      case action do
        "interact" when peer_count > 0 -> 1.3 # Boost social actions in federation
        "explore" when length(node_capabilities) > 0 -> 1.2 # Boost exploration with capabilities
        "migrate" when peer_count > 0 -> 1.4 # Boost migration when peers available
        _ -> 1.0 # Neutral impact
      end
    else
      1.0 # No federation impact
    end
  end

  defp build_action_reasoning(action, base_score, federation_modifier, federation) do
    base_reason = case action do
      "rest" -> "Need to restore energy levels"
      "think" -> "Time for reflection and planning"
      "explore" -> "Curiosity drives me to discover new things"
      "interact" -> "Social connection is important"
      "create" -> "I want to express my creativity"
      _ -> "This seems like a reasonable choice"
    end

    if federation_modifier > 1.0 and Map.get(federation, :federation_enabled, false) do
      "#{base_reason}. Federation context enhances this choice."
    else
      base_reason
    end
  end

  defp predict_outcome(action, stats, federation) do
    base_outcome = case action do
      "rest" -> "Increased energy and well-being"
      "think" -> "Greater clarity and insight"
      "explore" -> "New discoveries and experiences"
      "interact" -> "Social connections and collaboration"
      "create" -> "New creative expressions"
      _ -> "Unknown outcome"
    end

    if Map.get(federation, :federation_enabled, false) do
      "#{base_outcome} with potential for cross-node benefits"
    else
      base_outcome
    end
  end

  defp calculate_confidence(score, stats) do
    # Higher intelligence provides more confidence in decisions
    intelligence_factor = stats["intelligence"] / 100.0
    base_confidence = min(score, 1.0)

    # Boost confidence based on intelligence
    final_confidence = base_confidence + (intelligence_factor * 0.2)
    min(final_confidence, 1.0)
  end

  defp select_best_action(scored_actions) do
    scored_actions
    |> Enum.max_by(& &1.score)
  end

  defp select_backup_action(scored_actions, chosen_action) do
    scored_actions
    |> Enum.reject(&(&1.name == chosen_action.name))
    |> Enum.max_by(& &1.score, fn -> %{name: "think", score: 0.3} end)
    |> Map.get(:name)
  end

  # Memory Formation with Federation

  defp classify_memory_type(action, result) do
    success = Map.get(result, "success", false)

    case {action, success} do
      {"interact", true} -> "social_success"
      {"interact", false} -> "social_failure"
      {"explore", true} -> "discovery"
      {"explore", false} -> "failed_exploration"
      {"create", true} -> "creative_achievement"
      {"create", false} -> "creative_block"
      {_, true} -> "success"
      {_, false} -> "failure"
    end
  end

  defp assess_emotional_impact(result, traits) do
    success = Map.get(result, "success", false)
    intensity = Map.get(result, "intensity", 0.5)

    # Traits affect emotional intensity
    emotional_multiplier = if "sensitive" in traits, do: 1.3, else: 1.0

    base_impact = if success, do: intensity, else: -intensity
    base_impact * emotional_multiplier
  end

  defp extract_insights(action, result, traits, federation) do
    insights = []

    # Action-specific insights
    insights = case action do
      "interact" -> ["Social connections require effort and empathy" | insights]
      "explore" -> ["Exploration leads to growth and discovery" | insights]
      "create" -> ["Creativity requires both inspiration and persistence" | insights]
      _ -> insights
    end

    # Success/failure insights
    insights = if Map.get(result, "success", false) do
      ["This approach was effective and should be remembered" | insights]
    else
      ["This approach didn't work - need to try differently next time" | insights]
    end

    # Federation insights
    insights = if Map.get(federation, :federation_enabled, false) do
      ["Federation context influences outcomes and opportunities" | insights]
    else
      insights
    end

    insights
  end

  defp calculate_importance(result, memory_type) do
    base_importance = case memory_type do
      "social_success" -> 0.7
      "social_failure" -> 0.6
      "discovery" -> 0.8
      "creative_achievement" -> 0.9
      "failed_exploration" -> 0.4
      "creative_block" -> 0.5
      "success" -> 0.6
      "failure" -> 0.5
    end

    # Adjust based on result intensity
    intensity = Map.get(result, "intensity", 0.5)
    base_importance + (intensity * 0.2)
  end

  defp assess_federation_relevance(action, result, federation) do
    if Map.get(federation, :federation_enabled, false) do
      case action do
        "interact" -> 0.8 # High federation relevance
        "explore" -> 0.6 # Medium federation relevance
        "migrate" -> 0.9 # Very high federation relevance
        _ -> 0.3 # Low federation relevance
      end
    else
      0.0 # No federation relevance
    end
  end

  defp determine_sharing_eligibility(memory_type, importance) do
    # Determine if memory should be shared across federation
    case memory_type do
      "discovery" when importance > 0.7 -> "high_value_sharing"
      "social_success" -> "social_network_sharing"
      "creative_achievement" when importance > 0.8 -> "inspiration_sharing"
      _ when importance > 0.9 -> "critical_sharing"
      _ -> "local_only"
    end
  end

  defp assess_cross_node_impact(action, federation) do
    if Map.get(federation, :federation_enabled, false) do
      case action.name do
        "migrate" -> "Will transfer to another supervisor node"
        "interact" -> "May involve cross-node collaboration"
        "explore" -> "Could discover federation-wide resources"
        _ -> "Local action with minimal cross-node impact"
      end
    else
      "No cross-node impact - operating standalone"
    end
  end

  # Fallback Implementation

  defp generate_generic_response(context) do
    agent_name = Map.get(context, :agent_name, "Agent")

    response = %{
      "message" => "#{agent_name} is thinking...",
      "action" => "think",
      "reasoning" => "Generic response for unknown reasoning type"
    }

    {:ok, response}
  end
  defp infer_emotional_state(stats, traits) do
    energy = Map.get(stats, "energy", 50)
    focus = Map.get(stats, "focus", 50)
    stress = Map.get(stats, "stress", 0)

    mood_traits = Enum.filter(traits, fn {trait, _} ->
      trait in ["optimism", "resilience", "anxiety", "confidence"]
    end)

    base_mood = cond do
      energy > 70 and stress < 30 -> "energetic"
      energy < 30 -> "tired"
      stress > 70 -> "stressed"
      focus > 70 -> "focused"
      true -> "neutral"
    end

    # Modify base mood based on personality traits
    modified_mood = Enum.reduce(mood_traits, base_mood, fn {trait, value}, mood ->
      case {trait, value} do
        {"optimism", val} when val > 70 and mood == "neutral" -> "optimistic"
        {"anxiety", val} when val > 60 -> "anxious"
        {"confidence", val} when val > 80 -> "confident"
        _ -> mood
      end
    end)

    %{
      "primary_mood" => modified_mood,
      "energy_level" => energy,
      "stress_level" => stress,
      "emotional_stability" => max(0, 100 - stress)
    }
  end

  defp build_memory_content(action, result, insights) do
    success_text = if Map.get(result, "success", false), do: "successfully", else: "unsuccessfully"

    content = "I #{success_text} performed #{action}."

    if not Enum.empty?(insights) do
      insight_text = Enum.join(insights, " ")
      "#{content} #{insight_text}"
    else
      content
    end
  end
end
