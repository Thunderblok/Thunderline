defmodule Thunderline.Agents.Actions.MakeDecision do
  @moduledoc """
  Action for PAC decision making based on assessed context.

  This action processes context assessment and uses AI reasoning to:
  - Prioritize needs and goals
  - Evaluate available options
  - Consider consequences and trade-offs
  - Select optimal actions
  - Generate reasoning explanations
  """

  use Jido.Action,
    name: "make_decision",
    description: "Make decisions based on context assessment",
    schema: [
      assessment: [type: :map, required: true],
      pac_config: [type: :map, required: true],
      reasoning_mode: [type: :atom, default: :balanced]
    ]

  require Logger

  alias Thunderline.MCP.PromptManager
  alias Thunderline.Agents.AIProvider

  @impl true
  def run(params, context) do
    %{
      assessment: assessment,
      pac_config: pac_config,
      reasoning_mode: mode
    } = params

    Logger.debug("Making decision for PAC #{pac_config[:pac_name]}")

    with {:ok, options} <- generate_options(assessment, pac_config),
         {:ok, priorities} <- establish_priorities(assessment, pac_config, mode),
         {:ok, decision} <- evaluate_and_choose(options, priorities, assessment),
         {:ok, reasoning} <- generate_reasoning(decision, assessment, options) do

      result = %{
        chosen_action: decision.action,
        reasoning: reasoning,
        confidence: decision.confidence,
        alternatives: decision.alternatives,
        priorities: priorities,
        timestamp: DateTime.utc_now()
      }

      Logger.debug("Decision made for PAC #{pac_config[:pac_name]}: #{decision.action}")
      {:ok, result}
    else
      {:error, reason} ->
        Logger.error("Decision making failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Decision Process Functions

  defp generate_options(assessment, pac_config) do
    base_options = [
      %{action: "rest", type: :maintenance, energy_cost: -20, requirements: []},
      %{action: "explore", type: :exploration, energy_cost: 15, requirements: ["curiosity"]},
      %{action: "socialize", type: :social, energy_cost: 10, requirements: ["social_opportunity"]},
      %{action: "create", type: :creative, energy_cost: 20, requirements: ["creativity"]},
      %{action: "learn", type: :intellectual, energy_cost: 15, requirements: ["intelligence"]},
      %{action: "reflect", type: :introspective, energy_cost: 5, requirements: []}
    ]

    # Filter options based on current situation and capabilities
    viable_options =
      base_options
      |> filter_by_energy(assessment.situation.energy_level)
      |> filter_by_capabilities(assessment.capabilities)
      |> filter_by_context(assessment.situation)
      |> add_tool_based_options(assessment.capabilities.applicable_tools)
      |> add_goal_based_options(assessment.needs.goal_progress)

    {:ok, viable_options}
  end

  defp establish_priorities(assessment, pac_config, mode) do
    base_priorities = %{
      survival: calculate_survival_priority(assessment.situation),
      growth: calculate_growth_priority(assessment.needs, pac_config),
      social: calculate_social_priority(assessment.needs, assessment.situation),
      achievement: calculate_achievement_priority(assessment.needs.goal_progress),
      exploration: calculate_exploration_priority(pac_config, assessment.situation)
    }

    # Adjust priorities based on reasoning mode and personality
    adjusted_priorities = adjust_for_mode(base_priorities, mode)
    |> adjust_for_personality(pac_config.personality)

    {:ok, adjusted_priorities}
  end
    defp evaluate_and_choose(options, priorities, assessment) do
    # Use AI reasoning for decision making
    decision_context = %{
      available_actions: Enum.map(options, & &1.action),
      assessment: assessment,
      priorities: priorities,
      pac_name: Map.get(assessment, :pac_name, "Unknown"),
      stats: Map.get(assessment, :stats, %{}),
      traits: Map.get(assessment, :traits, []),
      goals: Map.get(assessment, :goals, [])
    }

    prompt = PromptManager.generate_decision_prompt(decision_context)

    case AIProvider.reason(prompt, decision_context) do
      {:ok, ai_decision} ->
        decision = %{
          action: ai_decision["chosen_action"],
          confidence: ai_decision["confidence"] || 0.7,
          alternatives: [ai_decision["backup_plan"]],
          reasoning: ai_decision["reasoning"],
          expected_outcome: ai_decision["expected_outcome"]
        }
        {:ok, decision}

      {:error, reason} ->
        Logger.warning("AI reasoning failed, using fallback: #{inspect(reason)}")
        fallback_decision(options, priorities)
    end
  end

  defp fallback_decision(options, priorities) do
    # Simple fallback scoring
    scored_options =
      options
      |> Enum.map(&score_option(&1, priorities, %{}))
      |> Enum.sort_by(& &1.total_score, :desc)

    case scored_options do
      [best | rest] ->
        decision = %{
          action: best.action,
          confidence: 0.6,
          alternatives: Enum.take(rest, 2),
          reasoning: "Fallback decision based on priority scoring",
          expected_outcome: "Expected positive outcome"
        }
        {:ok, decision}

      [] ->
        {:error, :no_viable_options}
    end
  end
    defp generate_reasoning(decision, assessment, options) do
    # Reasoning is already included in the decision from AI provider
    reasoning_text = Map.get(decision, :reasoning, "No reasoning provided")
    {:ok, reasoning_text}
  end

  # Filtering Functions

  defp filter_by_energy(options, energy_level) do
    energy_threshold = case energy_level do
      "high" -> 30
      "medium" -> 20
      "low" -> 10
      "depleted" -> 0
    end

    Enum.filter(options, fn option ->
      option.energy_cost <= energy_threshold
    end)
  end

  defp filter_by_capabilities(options, capabilities) do
    applicable_tools = MapSet.new(capabilities.applicable_tools)

    Enum.filter(options, fn option ->
      required_tools = MapSet.new(option[:required_tools] || [])
      MapSet.subset?(required_tools, applicable_tools)
    end)
  end

  defp filter_by_context(options, situation) do
    Enum.filter(options, fn option ->
      case option.type do
        :social -> situation.social_context.other_pacs_present > 0
        :exploration -> situation.zone_type in [:open, :collaborative]
        _ -> true
      end
    end)
  end

  defp add_tool_based_options(options, tools) do
    tool_options =
      tools
      |> Enum.map(fn tool ->
        %{
          action: "use_#{tool}",
          type: :tool_usage,
          energy_cost: 10,
          requirements: [tool],
          tool: tool
        }
      end)

    options ++ tool_options
  end

  defp add_goal_based_options(options, goal_progress) do
    goal_options =
      goal_progress
      |> Enum.filter(fn goal -> goal.progress < 100 end)
      |> Enum.map(fn goal ->
        %{
          action: "work_on_goal",
          type: :goal_pursuit,
          energy_cost: 15,
          requirements: [],
          goal: goal.goal,
          urgency: goal.urgency
        }
      end)

    options ++ goal_options
  end

  # Priority Calculation Functions

  defp calculate_survival_priority(situation) do
    case situation.energy_level do
      "depleted" -> 1.0
      "low" -> 0.8
      "medium" -> 0.3
      "high" -> 0.1
    end
  end

  defp calculate_growth_priority(needs, pac_config) do
    base = 0.5

    learning_bonus = if needs.learning_needs.curiosity_level > 70, do: 0.3, else: 0.0
    creative_bonus = if needs.creative_needs.creative_energy > 70, do: 0.2, else: 0.0

    base + learning_bonus + creative_bonus
  end

  defp calculate_social_priority(needs, situation) do
    social_need = needs.social_needs.social_energy / 100.0
    opportunity = if situation.social_context.other_pacs_present > 0, do: 0.3, else: 0.0

    social_need + opportunity
  end

  defp calculate_achievement_priority(goal_progress) do
    if length(goal_progress) > 0 do
      avg_progress = goal_progress
      |> Enum.map(& &1.progress)
      |> Enum.sum()
      |> Kernel./(length(goal_progress))

      # Higher priority if goals are partially complete
      if avg_progress > 20 and avg_progress < 80, do: 0.8, else: 0.4
    else
      0.2  # Low priority if no goals
    end
  end

  defp calculate_exploration_priority(pac_config, situation) do
    curiosity = pac_config.stats["curiosity"] / 100.0
    exploration_bonus = if situation.zone_type == :exploration, do: 0.2, else: 0.0

    curiosity + exploration_bonus
  end

  # Scoring Functions

  defp score_option(option, priorities, assessment) do
    scores = %{
      survival: score_for_survival(option, priorities.survival),
      growth: score_for_growth(option, priorities.growth),
      social: score_for_social(option, priorities.social),
      achievement: score_for_achievement(option, priorities.achievement),
      exploration: score_for_exploration(option, priorities.exploration)
    }

    total_score = scores
    |> Map.values()
    |> Enum.sum()

    option
    |> Map.put(:score_breakdown, scores)
    |> Map.put(:total_score, total_score)
  end

  defp score_for_survival(option, priority) do
    case option.action do
      "rest" -> priority * 1.0
      action when action in ["explore", "create"] -> priority * -0.5
      _ -> 0.0
    end
  end

  defp score_for_growth(option, priority) do
    case option.type do
      :intellectual -> priority * 1.0
      :creative -> priority * 0.8
      :exploration -> priority * 0.6
      _ -> 0.0
    end
  end

  defp score_for_social(option, priority) do
    case option.type do
      :social -> priority * 1.0
      _ -> 0.0
    end
  end

  defp score_for_achievement(option, priority) do
    case option.action do
      "work_on_goal" -> priority * 1.0
      action when action in ["learn", "create"] -> priority * 0.5
      _ -> 0.0
    end
  end

  defp score_for_exploration(option, priority) do
    case option.type do
      :exploration -> priority * 1.0
      :tool_usage -> priority * 0.4
      _ -> 0.0
    end
  end

  # Adjustment Functions

  defp adjust_for_mode(priorities, mode) do
    case mode do
      :conservative ->
        priorities
        |> Map.update(:survival, 0, & &1 * 1.5)
        |> Map.update(:exploration, 0, & &1 * 0.5)

      :aggressive ->
        priorities
        |> Map.update(:achievement, 0, & &1 * 1.5)
        |> Map.update(:exploration, 0, & &1 * 1.3)

      :social ->
        Map.update(priorities, :social, 0, & &1 * 1.4)

      :balanced ->
        priorities
    end
  end

  defp adjust_for_personality(priorities, personality) do
    case personality.decision_tendency do
      "exploratory" ->
        Map.update(priorities, :exploration, 0, & &1 * 1.3)

      "analytical" ->
        priorities
        |> Map.update(:growth, 0, & &1 * 1.2)
        |> Map.update(:achievement, 0, & &1 * 1.1)

      "innovative" ->
        priorities
        |> Map.update(:growth, 0, & &1 * 1.4)
        |> Map.update(:exploration, 0, & &1 * 1.2)

      "pragmatic" ->
        priorities
        |> Map.update(:achievement, 0, & &1 * 1.3)
        |> Map.update(:survival, 0, & &1 * 1.1)

      _ ->
        priorities
    end
  end

  # Utility Functions

  defp calculate_confidence(best, alternatives) do
    case alternatives do
      [] -> 1.0
      [second | _] ->
        score_diff = best.total_score - second.total_score
        min(1.0, max(0.1, score_diff / best.total_score))
    end
  end

  defp generate_fallback_reasoning(decision, assessment) do
    """
    Decided to #{decision.action} based on current situation analysis.
    Confidence level: #{trunc(decision.confidence * 100)}%.
    Primary factors: #{inspect(decision.score_breakdown)}
    """
  end
end
