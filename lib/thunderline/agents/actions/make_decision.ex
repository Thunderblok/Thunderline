defmodule Thunderline.Agents.Actions.MakeDecision do
  @moduledoc """
  Action for PAC Agent decision making based on assessed context.

  This action processes context assessment and uses AI reasoning to:
  - Prioritize needs and goals
  - Evaluate available options
  - Consider consequences and trade-offs
  - Select optimal actions
  - Generate reasoning explanations
  - Account for federation and cross-node considerations
  """

  use Jido.Action,
    name: "make_decision",
    description: "Make decisions based on context assessment",
    schema: [
      assessment: [type: :map, required: true],
      agent_config: [type: :map, required: true],
      reasoning_mode: [type: :atom, default: :balanced]
    ]

  require Logger

  alias Thunderline.MCP.PromptManager
  alias Thunderline.Agents.AIProvider

  @impl true
  def run(params, context) do
    %{
      assessment: assessment,
      agent_config: agent_config,
      reasoning_mode: mode
    } = params

    Logger.debug("Making decision for PAC Agent #{agent_config[:agent_name]}")

    with {:ok, options} <- generate_options(assessment, agent_config),
         {:ok, priorities} <- establish_priorities(assessment, agent_config, mode),
         {:ok, decision} <- evaluate_and_choose(options, priorities, assessment),
         {:ok, reasoning} <- generate_reasoning(decision, assessment, options) do

      result = %{
        chosen_action: decision.action,
        reasoning: reasoning,
        confidence: decision.confidence,
        alternatives: decision.alternatives,
        priorities: priorities,
        timestamp: DateTime.utc_now(),
        federation_context: Map.get(assessment, :federation_context, %{})
      }

      Logger.debug("Decision made for PAC Agent #{agent_config[:agent_name]}: #{decision.action}")
      {:ok, result}
    else
      {:error, reason} ->
        Logger.error("Decision making failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Decision Process Functions

  defp generate_options(assessment, agent_config) do
    base_options = [
      %{action: "rest", type: :maintenance, energy_cost: -20, requirements: []},
      %{action: "reflect", type: :introspective, energy_cost: 5, requirements: []},
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
      |> add_federation_options(Map.get(assessment, :federation_context, %{}))

    {:ok, viable_options}
  end

  defp establish_priorities(assessment, agent_config, mode) do
    base_priorities = %{
      survival: calculate_survival_priority(assessment.situation),
      growth: calculate_growth_priority(assessment.needs, agent_config),
      social: calculate_social_priority(assessment.needs, assessment.situation),
      achievement: calculate_achievement_priority(assessment.needs.goal_progress),
      exploration: calculate_exploration_priority(agent_config, assessment.situation)
    }

    # Adjust priorities based on reasoning mode and personality
    adjusted_priorities = adjust_for_mode(base_priorities, mode)
    |> adjust_for_personality(agent_config.personality)
    |> adjust_for_federation(Map.get(assessment, :federation_context, %{}))

    {:ok, adjusted_priorities}
  end

  defp evaluate_and_choose(options, priorities, assessment) do
    # Use AI reasoning for decision making
    decision_context = %{
      available_actions: Enum.map(options, & &1.action),
      assessment: assessment,
      priorities: priorities,
      agent_name: Map.get(assessment, :agent_name, "Unknown"),
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
      energy_cost = Map.get(option, :energy_cost, 0)
      energy_cost <= energy_threshold
    end)
  end

  defp filter_by_capabilities(options, capabilities) do
    applicable_tools = capabilities.applicable_tools

    Enum.filter(options, fn option ->
      required_tools = Map.get(option, :required_tools, [])
      Enum.all?(required_tools, &(&1 in applicable_tools))
    end)
  end

  defp filter_by_context(options, situation) do
    # Filter based on environmental context
    case situation.zone_type do
      "social" ->
        # Favor social actions in social zones
        Enum.map(options, fn option ->
          if option.type == :social do
            Map.update(option, :priority_bonus, 10, &(&1 + 10))
          else
            option
          end
        end)

      "creative" ->
        # Favor creative actions in creative zones
        Enum.map(options, fn option ->
          if option.type == :creative do
            Map.update(option, :priority_bonus, 10, &(&1 + 10))
          else
            option
          end
        end)

      _ ->
        options
    end
  end

  defp add_tool_based_options(options, applicable_tools) do
    tool_options = Enum.map(applicable_tools, fn tool ->
      %{
        action: "use_#{tool}",
        type: :tool_usage,
        energy_cost: 12,
        requirements: [tool],
        tool: tool
      }
    end)

    options ++ tool_options
  end

  defp add_goal_based_options(options, goal_progress) do
    goal_options = goal_progress
    |> Enum.filter(fn goal -> goal.progress < 100 end)
    |> Enum.map(fn goal ->
      %{
        action: "work_on_goal",
        type: :goal_pursuit,
        energy_cost: 18,
        requirements: [],
        goal: goal.goal
      }
    end)

    options ++ goal_options
  end

  defp add_federation_options(options, federation_context) do
    # Add federation-specific options based on context
    federation_options = case Map.get(federation_context, :coordination_requests, []) do
      [] -> []
      requests ->
        Enum.map(requests, fn request ->
          %{
            action: "coordinate_#{request.type}",
            type: :federation,
            energy_cost: 15,
            requirements: ["federation_ready"],
            federation_task: request
          }
        end)
    end

    options ++ federation_options
  end

  # Priority Calculation

  defp calculate_survival_priority(situation) do
    base = 0.3

    case situation.energy_level do
      "depleted" -> base + 0.7
      "low" -> base + 0.4
      "medium" -> base + 0.1
      "high" -> base
    end
  end

  defp calculate_growth_priority(needs, agent_config) do
    base = 0.4

    learning_bonus = if needs.learning_needs.curiosity_level > 70, do: 0.3, else: 0.0
    creative_bonus = if needs.creative_needs.creative_energy > 70, do: 0.2, else: 0.0

    base + learning_bonus + creative_bonus
  end

  defp calculate_social_priority(needs, situation) do
    base = 0.2

    social_bonus = case needs.social_needs.interaction_preference do
      "seeks" -> 0.4
      "neutral" -> 0.1
      _ -> 0.0
    end

    presence_bonus = if situation.social_context.other_agents_present > 0, do: 0.2, else: 0.0

    base + social_bonus + presence_bonus
  end

  defp calculate_achievement_priority(goal_progress) do
    if length(goal_progress) > 0 do
      avg_progress = Enum.map(goal_progress, & &1.progress) |> Enum.sum() |> div(length(goal_progress))
      0.3 + (100 - avg_progress) / 200  # Higher priority for less complete goals
    else
      0.1
    end
  end

  defp calculate_exploration_priority(agent_config, situation) do
    base = 0.3

    curiosity_bonus = if agent_config.stats["curiosity"] > 70, do: 0.3, else: 0.0
    zone_bonus = if situation.zone_type == "exploration", do: 0.2, else: 0.0

    base + curiosity_bonus + zone_bonus
  end

  # Priority Adjustments

  defp adjust_for_mode(priorities, mode) do
    case mode do
      :survival -> Map.update!(priorities, :survival, &(&1 * 1.5))
      :growth -> Map.update!(priorities, :growth, &(&1 * 1.4))
      :social -> Map.update!(priorities, :social, &(&1 * 1.3))
      :exploration -> Map.update!(priorities, :exploration, &(&1 * 1.3))
      :balanced -> priorities
    end
  end

  defp adjust_for_personality(priorities, personality) do
    case personality.decision_tendency do
      "exploratory" -> Map.update!(priorities, :exploration, &(&1 * 1.2))
      "analytical" -> Map.update!(priorities, :growth, &(&1 * 1.2))
      "social" -> Map.update!(priorities, :social, &(&1 * 1.2))
      _ -> priorities
    end
  end

  defp adjust_for_federation(priorities, federation_context) do
    # Adjust priorities based on federation needs
    case Map.get(federation_context, :coordination_priority, :normal) do
      :high -> Map.put(priorities, :federation, 0.8)
      :medium -> Map.put(priorities, :federation, 0.4)
      :low -> Map.put(priorities, :federation, 0.1)
      _ -> priorities
    end
  end

  # Option Scoring

  defp score_option(option, priorities, context) do
    base_score = 50

    # Score based on action type alignment with priorities
    type_score = case option.type do
      :maintenance -> priorities.survival * 100
      :social -> priorities.social * 100
      :creative -> priorities.growth * 80
      :intellectual -> priorities.growth * 90
      :exploration -> priorities.exploration * 100
      :goal_pursuit -> priorities.achievement * 100
      :federation -> Map.get(priorities, :federation, 0.0) * 100
      _ -> 30
    end

    # Apply energy cost penalty
    energy_penalty = option.energy_cost * 0.5

    # Apply priority bonus if present
    priority_bonus = Map.get(option, :priority_bonus, 0)

    total_score = base_score + type_score - energy_penalty + priority_bonus

    Map.put(option, :total_score, total_score)
  end
end
