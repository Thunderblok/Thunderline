defmodule Thunderline.AgentCore.DecisionEngine do
  @moduledoc """
  Chooses the next action based on PAC state (agent_config) and context (assessment).
  Orchestrates option generation, priority establishment, and final decision evaluation.
  """

  require Logger
  alias Thunderline.MCP.PromptManager
  alias Thunderline.Agents.AIProvider
  # Note: Thunderline.PAC.Agent might be needed if agent_config is expected to be a strict struct
  # and not just a map, but current usage suggests map access (e.g. agent_config.stats).

  # The Decision struct from the stub is not used directly, as evaluate_and_choose returns a richer map.
  # If a strict struct is needed later, this can be (re)defined and populated from the map.
  # defmodule Decision do
  #   @moduledoc "A decision struct with action, reason, and modifiers."
  #   defstruct [:action, :reason, :mods]
  # end

  @type assessment :: map()
  # Contains .stats, .personality etc.
  @type agent_config :: map()
  @type reasoning_mode :: :balanced | :survival | :growth | :social | :exploration
  # The rich map from evaluate_and_choose
  @type decision_struct :: map()
  @type metadata :: map()

  @spec make_decision(assessment(), agent_config(), reasoning_mode()) ::
          {:ok, {decision_struct(), metadata()}} | {:error, any()}
  def make_decision(assessment, agent_config, reasoning_mode \\ :balanced) do
    with {:ok, options} <- generate_options(assessment, agent_config),
         {:ok, priorities} <- establish_priorities(assessment, agent_config, reasoning_mode),
         {:ok, decision} <- evaluate_and_choose(options, priorities, assessment, agent_config),
         {:ok, reasoning_text} <- generate_reasoning(decision, assessment, options) do
      final_decision = Map.put_if_absent(decision, :reasoning, reasoning_text)

      metadata = %{
        timestamp: DateTime.utc_now(),
        options_considered: Enum.map(options, & &1.action),
        priorities: priorities,
        reasoning_mode: reasoning_mode
      }

      {:ok, {final_decision, metadata}}
    else
      {:error, reason} ->
        Logger.error("Decision engine failed: #{inspect(reason)}")
        {:error, reason}

      err ->
        Logger.error("Decision engine unexpected error: #{inspect(err)}")
        {:error, :unexpected_decision_engine_error}
    end
  end

  # Decision Process Functions (Copied from Thunderline.Agents.Actions.MakeDecision)

  defp generate_options(assessment, agent_config) do
    base_options = [
      %{action: "rest", type: :maintenance, energy_cost: -20, requirements: []},
      %{action: "reflect", type: :introspective, energy_cost: 5, requirements: []},
      %{action: "explore", type: :exploration, energy_cost: 15, requirements: ["curiosity"]},
      %{
        action: "socialize",
        type: :social,
        energy_cost: 10,
        requirements: ["social_opportunity"]
      },
      %{action: "create", type: :creative, energy_cost: 20, requirements: ["creativity"]},
      %{action: "learn", type: :intellectual, energy_cost: 15, requirements: ["intelligence"]}
      # duplicate reflect removed, ensure it was intended or add back if necessary
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
    adjusted_priorities =
      base_priorities
      |> adjust_for_mode(mode)
      # agent_config assumed to have .personality
      |> adjust_for_personality(agent_config.personality)
      |> adjust_for_federation(Map.get(assessment, :federation_context, %{}))

    {:ok, adjusted_priorities}
  end

  # evaluate_and_choose needs agent_config for fallback_decision context
  defp evaluate_and_choose(options, priorities, assessment, agent_config) do
    decision_context = %{
      available_actions: Enum.map(options, & &1.action),
      # Full assessment available to prompt
      assessment: assessment,
      priorities: priorities,
      # agent_name, stats, traits, goals are often part of assessment.situation or assessment.needs
      # If not, ensure they are correctly passed or retrieved from agent_config if that's their source
      # Assuming name is in agent_config
      agent_name: Map.get(agent_config, :name, "Unknown"),
      # Assuming stats in agent_config
      stats: Map.get(agent_config, :stats, %{}),
      # Assuming traits in agent_config
      traits: Map.get(agent_config, :traits, []),
      # Goals are in assessment.needs
      goals: Map.get(assessment.needs, :goal_progress, [])
    }

    prompt = PromptManager.generate_decision_prompt(decision_context)

    case AIProvider.reason(prompt, decision_context) do
      {:ok, ai_decision} ->
        decision = %{
          action: ai_decision["chosen_action"],
          confidence: ai_decision["confidence"] || 0.7,
          # Ensure this is a list
          alternatives: [ai_decision["backup_plan"]],
          reasoning: ai_decision["reasoning"],
          expected_outcome: ai_decision["expected_outcome"]
        }

        {:ok, decision}

      {:error, reason} ->
        Logger.warning("AI reasoning failed, using fallback: #{inspect(reason)}")
        # Pass assessment and agent_config
        fallback_decision(options, priorities, assessment, agent_config)
    end
  end

  defp fallback_decision(options, priorities, assessment, agent_config) do
    # Simple fallback scoring
    # Context for score_option now includes assessment and agent_config for richer scoring if needed
    scored_options =
      options
      |> Enum.map(
        &score_option(&1, priorities, %{assessment: assessment, agent_config: agent_config})
      )
      |> Enum.sort_by(& &1.total_score, :desc)

    case scored_options do
      [best | rest] ->
        decision = %{
          action: best.action,
          confidence: 0.6,
          # ensure alternatives is a list of actions
          alternatives: Enum.map(Enum.take(rest, 2), & &1.action),
          reasoning:
            "Fallback decision based on priority scoring. Energy: #{assessment.situation.energy_level}, Mood: #{assessment.situation.mood_state}",
          expected_outcome: "Expected positive outcome based on current priorities."
        }

        {:ok, decision}

      [] ->
        # If no options, default to a safe action like 'reflect' or 'idle'
        Logger.warning("No viable options in fallback, defaulting to :reflect")

        decision = %{
          action: "reflect",
          confidence: 0.5,
          alternatives: [],
          reasoning: "No viable options found in fallback, defaulting to reflect.",
          expected_outcome: "Gather more information or wait for conditions to change."
        }

        {:ok, decision}
    end
  end

  defp generate_reasoning(decision, _assessment, _options) do
    # Reasoning is typically included in the decision from AI provider or fallback.
    # This function can augment it or provide a default if missing.
    reasoning_text =
      Map.get(decision, :reasoning, "No specific reasoning provided by the core engine.")

    {:ok, reasoning_text}
  end

  # Filtering Functions

  defp filter_by_energy(options, energy_level) do
    energy_threshold =
      case energy_level do
        "high" -> 30
        "medium" -> 20
        "low" -> 10
        "depleted" -> 0
        # Default for unknown energy levels
        _ -> 5
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
        Enum.map(options, fn option ->
          if option.type == :social do
            Map.update(option, :priority_bonus, 10, &(&1 + 10))
          else
            option
          end
        end)

      "creative" ->
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

  defp add_tool_based_options(options, applicable_tools) when is_list(applicable_tools) do
    tool_options =
      Enum.map(applicable_tools, fn tool ->
        %{
          action: "use_#{tool}",
          type: :tool_usage,
          # Example cost, could be tool-specific
          energy_cost: 12,
          # Could include skill requirements
          requirements: [tool],
          tool: tool
        }
      end)

    options ++ tool_options
  end

  defp add_tool_based_options(options, _), do: options

  defp add_goal_based_options(options, goal_progress) when is_list(goal_progress) do
    goal_options =
      goal_progress
      |> Enum.filter(fn goal -> (goal["progress"] || 0) < 100 end)
      |> Enum.map(fn goal ->
        %{
          # More specific action name
          action: "work_on_goal_#{goal["goal"] || "unnamed"}",
          type: :goal_pursuit,
          # Example cost
          energy_cost: 18,
          # Could include resource or state requirements
          requirements: [],
          # Reference to the goal
          goal_id: goal["goal_id"] || goal["goal"],
          goal_description: goal["description"] || goal["goal"]
        }
      end)

    options ++ goal_options
  end

  defp add_goal_based_options(options, _), do: options

  defp add_federation_options(options, federation_context) when is_map(federation_context) do
    federation_options =
      case Map.get(federation_context, :coordination_requests, []) do
        [] ->
          []

        requests when is_list(requests) ->
          Enum.map(requests, fn request ->
            %{
              action: "coordinate_#{request.type}",
              type: :federation,
              energy_cost: 15,
              # Example requirement
              requirements: ["federation_ready"],
              federation_task: request
            }
          end)

        # Handle malformed requests
        _ ->
          []
      end

    options ++ federation_options
  end

  defp add_federation_options(options, _), do: options

  # Priority Calculation

  defp calculate_survival_priority(situation) do
    base = 0.3
    # Ensure situation and energy_level are present
    energy_level = Map.get(situation, :energy_level, "medium")

    case energy_level do
      "depleted" -> base + 0.7
      "low" -> base + 0.4
      "medium" -> base + 0.1
      "high" -> base
      # Default for unknown
      _ -> base
    end
  end

  defp calculate_growth_priority(needs, agent_config) do
    base = 0.4
    # Ensure needs substructures and agent_config are present
    learning_needs = Map.get(needs, :learning_needs, %{})
    creative_needs = Map.get(needs, :creative_needs, %{})

    learning_bonus = if Map.get(learning_needs, :curiosity_level, 0) > 70, do: 0.3, else: 0.0
    creative_bonus = if Map.get(creative_needs, :creative_energy, 0) > 70, do: 0.2, else: 0.0

    base + learning_bonus + creative_bonus
  end

  defp calculate_social_priority(needs, situation) do
    base = 0.2
    social_needs = Map.get(needs, :social_needs, %{})
    social_context = Map.get(situation, :social_context, %{})

    social_bonus =
      case Map.get(social_needs, :interaction_preference, "neutral") do
        "seeks" -> 0.4
        "neutral" -> 0.1
        _ -> 0.0
      end

    presence_bonus = if Map.get(social_context, :other_agents_present, 0) > 0, do: 0.2, else: 0.0

    base + social_bonus + presence_bonus
  end

  defp calculate_achievement_priority(goal_progress)
       when is_list(goal_progress) and goal_progress != [] do
    valid_goals = Enum.filter(goal_progress, &is_map/1)

    if Enum.empty?(valid_goals) do
      0.1
    else
      avg_progress =
        Enum.map(valid_goals, &Map.get(&1, :progress, 0))
        |> Enum.sum()
        |> div(length(valid_goals))

      # Higher priority for less complete goals
      0.3 + (100 - avg_progress) / 200
    end
  end

  defp calculate_achievement_priority(_), do: 0.1

  defp calculate_exploration_priority(agent_config, situation) do
    base = 0.3
    stats = Map.get(agent_config, :stats, %{})
    zone_type = Map.get(situation, :zone_type, "unknown")

    curiosity_bonus = if Map.get(stats, "curiosity", 0) > 70, do: 0.3, else: 0.0
    zone_bonus = if zone_type == "exploration", do: 0.2, else: 0.0

    base + curiosity_bonus + zone_bonus
  end

  # Priority Adjustments

  defp adjust_for_mode(priorities, mode) do
    case mode do
      :survival ->
        Map.update(priorities, :survival, priorities.survival || 0, &(&1 * 1.5))

      :growth ->
        Map.update(priorities, :growth, priorities.growth || 0, &(&1 * 1.4))

      :social ->
        Map.update(priorities, :social, priorities.social || 0, &(&1 * 1.3))

      :exploration ->
        Map.update(priorities, :exploration, priorities.exploration || 0, &(&1 * 1.3))

      :balanced ->
        priorities

      # Unknown mode
      _ ->
        priorities
    end
  end

  defp adjust_for_personality(priorities, personality) when is_map(personality) do
    # Ensure personality is a map
    case Map.get(personality, :decision_tendency) do
      "exploratory" ->
        Map.update(priorities, :exploration, priorities.exploration || 0, &(&1 * 1.2))

      "analytical" ->
        Map.update(priorities, :growth, priorities.growth || 0, &(&1 * 1.2))

      "social" ->
        Map.update(priorities, :social, priorities.social || 0, &(&1 * 1.2))

      _ ->
        priorities
    end
  end

  # Non-map personality
  defp adjust_for_personality(priorities, _), do: priorities

  defp adjust_for_federation(priorities, federation_context) when is_map(federation_context) do
    # Adjust priorities based on federation needs
    case Map.get(federation_context, :coordination_priority, :normal) do
      # Consider if :federation key always exists or needs default
      :high -> Map.put(priorities, :federation, 0.8)
      :medium -> Map.put(priorities, :federation, 0.4)
      :low -> Map.put(priorities, :federation, 0.1)
      # Includes :normal or unknown
      _ -> priorities
    end
  end

  # Non-map context
  defp adjust_for_federation(priorities, _), do: priorities

  # Option Scoring

  defp score_option(option, priorities, context) when is_map(option) and is_map(priorities) do
    # Use float for scores
    base_score = 50.0

    # Score based on action type alignment with priorities
    type_score =
      case option.type do
        :maintenance -> (priorities.survival || 0.0) * 100.0
        :social -> (priorities.social || 0.0) * 100.0
        :creative -> (priorities.growth || 0.0) * 80.0
        :intellectual -> (priorities.growth || 0.0) * 90.0
        :exploration -> (priorities.exploration || 0.0) * 100.0
        :goal_pursuit -> (priorities.achievement || 0.0) * 100.0
        :federation -> Map.get(priorities, :federation, 0.0) * 100.0
        # Add a generic utility score for tools
        :tool_usage -> Map.get(priorities, :utility, 0.3) * 70.0
        _ -> 30.0
      end

    # Apply energy cost penalty
    energy_penalty = (Map.get(option, :energy_cost, 0) || 0) * 0.5

    # Apply priority bonus if present
    priority_bonus = (Map.get(option, :priority_bonus, 0) || 0) * 1.0

    total_score = base_score + type_score - energy_penalty + priority_bonus

    Map.put(option, :total_score, total_score)
  end

  # Return option as is if inputs are not as expected
  defp score_option(option, _, _), do: option
end
