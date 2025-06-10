defmodule Thunderline.Agents.AIProvider do
  @moduledoc """
  Simple AI provider for PAC reasoning using prompt templates.

  This module provides a basic implementation of AI reasoning
  for PACs using pre-defined prompt templates and simple
  rule-based decision making.

  In a production system, this would integrate with:
  - OpenAI API
  - Anthropic Claude
  - Local LLM via Ollama
  - Or other AI reasoning services
  """

  require Logger

  alias Thunderline.MCP.PromptManager

  @doc """
  Generate AI reasoning response for a given prompt and context.
  """
  @spec reason(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def reason(prompt, context) do
    # For now, use rule-based reasoning
    # In production, this would call an actual AI service
    case extract_reasoning_type(prompt) do
      :context_assessment -> generate_context_assessment(context)
      :decision_making -> generate_decision(context)
      :memory_formation -> generate_memory(context)
      _ -> generate_generic_response(context)
    end
  end

  @doc """
  Generate a context assessment using rule-based logic.
  """
  def generate_context_assessment(context) do
    pac_name = Map.get(context, :pac_name, "Unknown")
    stats = Map.get(context, :stats, %{})
    traits = Map.get(context, :traits, [])
    environment = Map.get(context, :environment_context, %{})

    observations = build_observations(stats, traits, environment)
    emotional_state = infer_emotional_state(stats, traits)
    opportunities = identify_opportunities(environment, stats)
    threats = identify_threats(environment, stats)
    resources = assess_resources(stats, context)
    priorities = determine_priorities(stats, traits)

    assessment = %{
      "observations" => observations,
      "emotional_state" => emotional_state,
      "opportunities" => opportunities,
      "threats" => threats,
      "resources" => resources,
      "priorities" => priorities
    }

    Logger.debug("Generated context assessment for #{pac_name}")
    {:ok, assessment}
  end

  @doc """
  Generate a decision using rule-based logic.
  """
  def generate_decision(context) do
    available_actions = Map.get(context, :available_actions, [])
    assessment = Map.get(context, :assessment, %{})
    goals = Map.get(context, :goals, [])
    stats = Map.get(context, :stats, %{})
    traits = Map.get(context, :traits, [])

    scored_actions = score_actions(available_actions, assessment, goals, stats, traits)
    chosen_action = select_best_action(scored_actions)

    decision = %{
      "chosen_action" => chosen_action.name,
      "reasoning" => chosen_action.reasoning,
      "expected_outcome" => chosen_action.expected_outcome,
      "confidence" => chosen_action.confidence,
      "backup_plan" => select_backup_action(scored_actions, chosen_action)
    }

    Logger.debug("Generated decision: #{chosen_action.name}")
    {:ok, decision}
  end

  @doc """
  Generate a memory using rule-based logic.
  """
  def generate_memory(context) do
    action = Map.get(context, :action, "unknown_action")
    result = Map.get(context, :result, %{})
    traits = Map.get(context, :traits, [])

    memory_type = classify_memory_type(action, result)
    emotional_impact = assess_emotional_impact(result, traits)
    insights = extract_insights(action, result, traits)
    importance = calculate_importance(result, memory_type)
    tags = generate_tags(action, result, memory_type)

    memory = %{
      "memory_type" => memory_type,
      "summary" => generate_summary(action, result),
      "emotional_impact" => emotional_impact,
      "insights" => insights,
      "importance" => importance,
      "tags" => tags
    }

    Logger.debug("Generated memory of type: #{memory_type}")
    {:ok, memory}
  end

  # Private Functions

  defp extract_reasoning_type(prompt) do
    cond do
      String.contains?(prompt, "assess your current situation") -> :context_assessment
      String.contains?(prompt, "facing a decision") -> :decision_making
      String.contains?(prompt, "processing a recent experience") -> :memory_formation
      true -> :generic
    end
  end

  defp build_observations(stats, traits, environment) do
    observations = []

    observations = if stats["energy"] && stats["energy"] < 30 do
      ["Feeling low on energy" | observations]
    else
      observations
    end

    observations = if "curious" in traits do
      ["Notice interesting opportunities for exploration" | observations]
    else
      observations
    end

    observations = if Map.get(environment, :zone_type) == "social" do
      ["In a social environment with other PACs" | observations]
    else
      observations
    end

    Enum.take(observations ++ ["Environment seems stable", "Routine situation"], 3)
  end

  defp infer_emotional_state(stats, traits) do
    energy = Map.get(stats, "energy", 50)
    mood = Map.get(stats, "mood", 50)

    cond do
      energy > 70 and mood > 70 -> "energetic and optimistic"
      energy < 30 -> "tired and contemplative"
      mood < 30 -> "reflective and cautious"
      "social" in traits -> "socially engaged"
      true -> "balanced and alert"
    end
  end

  defp identify_opportunities(environment, stats) do
    opportunities = []

    opportunities = if Map.get(stats, "curiosity", 0) > 60 do
      ["Explore new areas or ideas" | opportunities]
    else
      opportunities
    end

    opportunities = if Map.get(environment, :has_other_pacs) do
      ["Social interaction with other PACs" | opportunities]
    else
      opportunities
    end

    Enum.take(opportunities ++ ["Rest and recharge"], 2)
  end

  defp identify_threats(environment, stats) do
    threats = []

    threats = if Map.get(stats, "energy", 50) < 20 do
      ["Energy depletion" | threats]
    else
      threats
    end

    Enum.take(threats ++ ["No immediate threats"], 2)
  end

  defp assess_resources(stats, context) do
    resources = []

    resources = if Map.get(stats, "energy", 0) > 50 do
      ["Sufficient energy" | resources]
    else
      resources
    end

    tools = Map.get(context, :available_tools, [])
    if length(tools) > 0 do
      ["Available tools: #{Enum.join(tools, ", ")}" | resources]
    else
      resources
    end
  end

  defp determine_priorities(stats, traits) do
    priorities = []

    priorities = if Map.get(stats, "energy", 50) < 40 do
      ["Energy management" | priorities]
    else
      priorities
    end

    priorities = if "social" in traits do
      ["Social connections" | priorities]
    else
      priorities
    end

    priorities = if "curious" in traits do
      ["Learning and exploration" | priorities]
    else
      priorities
    end

    Enum.take(priorities ++ ["General wellbeing"], 3)
  end

  defp score_actions(actions, assessment, goals, stats, traits) do
    actions
    |> Enum.map(fn action ->
      score = calculate_action_score(action, assessment, goals, stats, traits)

      %{
        name: action,
        score: score,
        reasoning: generate_action_reasoning(action, score, traits),
        expected_outcome: generate_expected_outcome(action, stats),
        confidence: min(score / 100.0, 0.95)
      }
    end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  defp calculate_action_score(action, assessment, goals, stats, traits) do
    base_score = 50

    # Energy considerations
    score = if String.contains?(action, "rest") and Map.get(stats, "energy", 50) < 40 do
      base_score + 30
    else
      base_score
    end

    # Trait alignment
    score = if String.contains?(action, "social") and "social" in traits do
      score + 20
    else
      score
    end

    score = if String.contains?(action, "explore") and "curious" in traits do
      score + 15
    else
      score
    end

    # Add randomness to prevent deterministic behavior
    score + Enum.random(-10..10)
  end

  defp generate_action_reasoning(action, score, traits) do
    if score > 70 do
      "This action aligns well with my current state and personality traits"
    else
      "A reasonable option given current circumstances"
    end
  end

  defp generate_expected_outcome(action, stats) do
    cond do
      String.contains?(action, "rest") -> "Restored energy and improved mood"
      String.contains?(action, "social") -> "Enhanced social connections"
      String.contains?(action, "explore") -> "New discoveries and learning"
      true -> "Positive progress toward goals"
    end
  end

  defp select_best_action(scored_actions) do
    List.first(scored_actions) || %{
      name: "wait",
      score: 30,
      reasoning: "No clear best option, waiting for better circumstances",
      expected_outcome: "Maintain status quo",
      confidence: 0.5
    }
  end

  defp select_backup_action(scored_actions, chosen_action) do
    backup = Enum.find(scored_actions, fn action ->
      action.name != chosen_action.name
    end)

    if backup, do: backup.name, else: "wait"
  end

  defp classify_memory_type(action, result) do
    cond do
      Map.get(result, :type) == :success -> "success"
      Map.get(result, :type) == :failure -> "failure"
      String.contains?(action, "social") -> "social"
      String.contains?(action, "explore") -> "discovery"
      true -> "learning"
    end
  end

  defp assess_emotional_impact(result, traits) do
    if Map.get(result, :positive, false) do
      "positive"
    else
      "neutral"
    end
  end

  defp extract_insights(action, result, traits) do
    insights = []

    insights = if Map.get(result, :energy_cost, 0) > 0 do
      ["Actions have energy costs" | insights]
    else
      insights
    end

    insights = if "social" in traits and String.contains?(action, "social") do
      ["Social interactions are rewarding" | insights]
    else
      insights
    end

    Enum.take(insights ++ ["Experience shapes understanding"], 2)
  end

  defp calculate_importance(result, memory_type) do
    base_importance = 0.5

    importance = if memory_type in ["success", "failure"] do
      base_importance + 0.2
    else
      base_importance
    end

    min(importance + Enum.random(0..20) / 100, 1.0)
  end

  defp generate_tags(action, result, memory_type) do
    tags = [memory_type]

    tags = if String.contains?(action, "social") do
      ["social" | tags]
    else
      tags
    end

    tags = if Map.get(result, :energy_cost, 0) > 10 do
      ["high_energy" | tags]
    else
      tags
    end

    Enum.uniq(tags)
  end

  defp generate_summary(action, result) do
    "Performed '#{action}' with result: #{inspect(result)}"
  end

  defp generate_generic_response(context) do
    {:ok, %{"response" => "Processing request", "confidence" => 0.5}}
  end
end
