defmodule Thunderline.Agents.Actions.ExecuteAction do
  @moduledoc """
  Action for executing PAC decisions using available tools and capabilities.

  This action translates high-level decisions into concrete actions by:
  - Routing to appropriate MCP tools
  - Managing action parameters and context
  - Handling action failures and retries
  - Tracking action results and side effects
  - Updating PAC state based on outcomes
  """

  use Jido.Action,
    name: "execute_action",
    description: "Execute chosen actions using available tools and capabilities",
    schema: [
      decision: [type: :map, required: true],
      pac_config: [type: :map, required: true],
      context: [type: :map, required: true],
      available_tools: [type: {:list, :string}, default: []]
    ]
    require Logger

  alias Thunderline.MCP.{ToolRouter, ToolRegistry}
  alias Thunderline.PAC.Manager

  @impl true
  def run(params, context) do
    %{
      decision: decision,
      pac_config: pac_config,
      context: action_context,
      available_tools: tools
    } = params

    action = decision.chosen_action
    pac_id = pac_config.pac_id

    Logger.debug("Executing action '#{action}' for PAC #{pac_config.pac_name}")

    with {:ok, action_plan} <- create_action_plan(action, decision, action_context),
         {:ok, execution_result} <- execute_action_plan(action_plan, pac_config, tools),
         {:ok, state_updates} <- calculate_state_updates(execution_result, pac_config),
         {:ok, _} <- apply_state_updates(pac_id, state_updates) do

      result = %{
        action: action,
        execution_result: execution_result,
        state_updates: state_updates,
        success: true,
        timestamp: DateTime.utc_now()
      }

      Logger.debug("Successfully executed action '#{action}' for PAC #{pac_config.pac_name}")
      {:ok, result}
    else
      {:error, reason} ->
        Logger.warn("Action execution failed for PAC #{pac_config.pac_name}: #{inspect(reason)}")

        # Return failure result with partial information
        failure_result = %{
          action: action,
          success: false,
          error: reason,
          timestamp: DateTime.utc_now()
        }

        {:ok, failure_result}  # Don't fail the whole tick on action failure
    end
  end

  # Action Planning

  defp create_action_plan(action, decision, context) do
    base_plan = %{
      action: action,
      type: classify_action_type(action),
      parameters: extract_action_parameters(action, decision),
      required_tools: determine_required_tools(action),
      estimated_duration: estimate_duration(action),
      prerequisites: check_prerequisites(action, context)
    }

    {:ok, base_plan}
  end

  defp classify_action_type(action) do
    cond do
      String.starts_with?(action, "use_") -> :tool_usage
      action in ["rest", "reflect"] -> :internal
      action in ["socialize", "communicate"] -> :social
      action in ["explore", "move"] -> :movement
      action in ["create", "build", "write"] -> :creative
      action in ["learn", "study", "analyze"] -> :intellectual
      action == "work_on_goal" -> :goal_pursuit
      true -> :general
    end
  end

  defp extract_action_parameters(action, decision) do
    base_params = %{
      action: action,
      confidence: decision.confidence,
      reasoning: decision.reasoning
    }

    # Add action-specific parameters
    case action do
      "use_" <> tool_name ->
        Map.put(base_params, :tool, tool_name)

      "work_on_goal" ->
        goal = decision.alternatives
        |> Enum.find(& &1.goal)
        |> Map.get(:goal, "unknown")

        Map.put(base_params, :goal, goal)

      _ ->
        base_params
    end
  end

  defp determine_required_tools(action) do
    case action do
      "use_" <> tool_name -> [tool_name]
      "explore" -> ["movement", "observation"]
      "create" -> ["creative_tools"]
      "learn" -> ["learning_tools"]
      "socialize" -> ["communication"]
      _ -> []
    end
  end

  defp estimate_duration(action) do
    # Duration in arbitrary "ticks" or time units
    case action do
      "rest" -> 1
      "reflect" -> 2
      "socialize" -> 3
      "explore" -> 4
      "create" -> 5
      "learn" -> 4
      "work_on_goal" -> 6
      _ -> 3
    end
  end

  defp check_prerequisites(action, context) do
    # Check if action can be performed given current context
    case action do
      "socialize" ->
        if context.zone_context["pac_count"] > 1 do
          []
        else
          ["no_other_pacs_available"]
        end

      "explore" ->
        if context.zone_context["exploration_allowed"] != false do
          []
        else
          ["exploration_restricted"]
        end

      _ ->
        []
    end
  end

  # Action Execution

  defp execute_action_plan(plan, pac_config, available_tools) do
    case plan.prerequisites do
      [] ->
        do_execute_action(plan, pac_config, available_tools)

      prerequisites ->
        {:error, {:prerequisites_not_met, prerequisites}}
    end
  end

  defp do_execute_action(plan, pac_config, available_tools) do
    case plan.type do
      :tool_usage ->
        execute_tool_action(plan, pac_config, available_tools)

      :internal ->
        execute_internal_action(plan, pac_config)

      :social ->
        execute_social_action(plan, pac_config)

      :movement ->
        execute_movement_action(plan, pac_config)

      :creative ->
        execute_creative_action(plan, pac_config)

      :intellectual ->
        execute_intellectual_action(plan, pac_config)

      :goal_pursuit ->
        execute_goal_action(plan, pac_config)

      :general ->
        execute_general_action(plan, pac_config)
    end
  end

  # Specific Action Executors
    defp execute_tool_action(plan, pac_config, available_tools) do
    tool_name = plan.parameters.tool

    if tool_name in available_tools do
      # Build execution context
      execution_context = %{
        pac_id: pac_config.pac_id,
        zone_id: Map.get(plan.parameters, :zone_id),
        tick_count: Map.get(plan.parameters, :tick_count, 0),
        agent_pid: self(),
        metadata: %{
          action_type: plan.type,
          action_name: plan.action
        }
      }

      # Execute tool through router
      tool_inputs = Map.drop(plan.parameters, [:tool, :zone_id, :tick_count])

      case ToolRouter.execute_tool(tool_name, tool_inputs, execution_context) do
        {:ok, result} ->
          {:ok, %{
            type: :tool_success,
            tool: tool_name,
            result: result,
            energy_cost: calculate_tool_energy_cost(tool_name, tool_inputs)
          }}

        {:error, :tool_not_found, message} ->
          {:error, {:tool_not_found, tool_name, message}}

        {:error, :invalid_input, details} ->
          {:error, {:invalid_tool_input, tool_name, details}}

        {:error, :execution_failed, reason} ->
          {:error, {:tool_execution_failed, tool_name, reason}}
      end
    else
      {:error, {:tool_not_available, tool_name}}
    end
  end

  defp execute_internal_action(plan, pac_config) do
    case plan.action do
      "rest" ->
        {:ok, %{
          type: :rest,
          energy_gained: 30,
          mood_effect: "refreshed",
          description: "#{pac_config.pac_name} took time to rest and recharge"
        }}

      "reflect" ->
        {:ok, %{
          type: :reflection,
          energy_cost: 5,
          intelligence_gain: 2,
          mood_effect: "contemplative",
          description: "#{pac_config.pac_name} engaged in deep reflection",
          insights: generate_reflection_insights(pac_config)
        }}

      _ ->
        {:error, {:unknown_internal_action, plan.action}}
    end
  end

  defp execute_social_action(plan, pac_config) do
    case plan.action do
      "socialize" ->
        {:ok, %{
          type: :social_interaction,
          energy_cost: 10,
          social_gain: 15,
          mood_effect: "social",
          description: "#{pac_config.pac_name} engaged in social interaction",
          interaction_type: "casual_conversation"
        }}

      _ ->
        {:error, {:unknown_social_action, plan.action}}
    end
  end

  defp execute_movement_action(plan, pac_config) do
    case plan.action do
      "explore" ->
        discoveries = generate_exploration_discoveries(pac_config)

        {:ok, %{
          type: :exploration,
          energy_cost: 15,
          curiosity_satisfaction: 20,
          mood_effect: "adventurous",
          description: "#{pac_config.pac_name} explored their environment",
          discoveries: discoveries
        }}

      _ ->
        {:error, {:unknown_movement_action, plan.action}}
    end
  end

  defp execute_creative_action(plan, pac_config) do
    case plan.action do
      "create" ->
        creation = generate_creative_output(pac_config)

        {:ok, %{
          type: :creation,
          energy_cost: 20,
          creativity_satisfaction: 25,
          mood_effect: "fulfilled",
          description: "#{pac_config.pac_name} engaged in creative work",
          creation: creation
        }}

      _ ->
        {:error, {:unknown_creative_action, plan.action}}
    end
  end

  defp execute_intellectual_action(plan, pac_config) do
    case plan.action do
      "learn" ->
        learning = generate_learning_outcome(pac_config)

        {:ok, %{
          type: :learning,
          energy_cost: 15,
          intelligence_gain: 10,
          mood_effect: "satisfied",
          description: "#{pac_config.pac_name} engaged in learning",
          learning: learning
        }}

      _ ->
        {:error, {:unknown_intellectual_action, plan.action}}
    end
  end

  defp execute_goal_action(plan, pac_config) do
    goal = plan.parameters.goal

    progress_made = Enum.random(10..30)

    {:ok, %{
      type: :goal_progress,
      energy_cost: 15,
      goal: goal,
      progress_made: progress_made,
      mood_effect: "determined",
      description: "#{pac_config.pac_name} made progress on goal: #{goal}"
    }}
  end

  defp execute_general_action(plan, pac_config) do
    {:ok, %{
      type: :general,
      energy_cost: 10,
      description: "#{pac_config.pac_name} performed #{plan.action}",
      action: plan.action
    }}
  end

  # State Updates

  defp calculate_state_updates(execution_result, pac_config) do
    base_updates = %{
      stats: %{},
      state: %{
        activity: execution_result.type || "idle",
        mood: execution_result.mood_effect || pac_config.stats["mood"]
      }
    }

    # Apply energy changes
    stats_updates = if execution_result[:energy_cost] do
      current_energy = pac_config.stats["energy"]
      new_energy = max(0, current_energy - execution_result.energy_cost)
      Map.put(base_updates.stats, "energy", new_energy)
    else
      base_updates.stats
    end

    stats_updates = if execution_result[:energy_gained] do
      current_energy = pac_config.stats["energy"]
      new_energy = min(100, current_energy + execution_result.energy_gained)
      Map.put(stats_updates, "energy", new_energy)
    else
      stats_updates
    end

    # Apply other stat changes
    stats_updates = apply_stat_gains(stats_updates, execution_result, pac_config)

    final_updates = %{base_updates | stats: stats_updates}

    {:ok, final_updates}
  end

  defp apply_stat_gains(stats_updates, execution_result, pac_config) do
    gains = [
      {:intelligence_gain, "intelligence"},
      {:creativity_gain, "creativity"},
      {:social_gain, "social"},
      {:curiosity_satisfaction, "curiosity"}
    ]

    Enum.reduce(gains, stats_updates, fn {gain_key, stat_name}, acc ->
      if gain_value = execution_result[gain_key] do
        current_value = pac_config.stats[stat_name] || 50
        new_value = min(100, current_value + gain_value)
        Map.put(acc, stat_name, new_value)
      else
        acc
      end
    end)
  end

  defp apply_state_updates(pac_id, updates) do
    # Use PAC manager to apply updates to the actual PAC record
    case Manager.update_pac_state(pac_id, updates) do
      {:ok, _updated_pac} -> {:ok, :applied}
      {:error, reason} -> {:error, reason}
    end
  end

  # Generation Functions

  defp generate_reflection_insights(pac_config) do
    insights = [
      "Understanding of personal goals became clearer",
      "Recognized patterns in recent behavior",
      "Gained perspective on recent interactions",
      "Identified areas for personal growth"
    ]

    Enum.take_random(insights, Enum.random(1..2))
  end

  defp generate_exploration_discoveries(pac_config) do
    discoveries = [
      "Discovered an interesting conversation thread",
      "Found a new tool or resource",
      "Uncovered an unexpected connection",
      "Explored a new area of knowledge",
      "Met an interesting perspective"
    ]

    Enum.take_random(discoveries, Enum.random(1..3))
  end

  defp generate_creative_output(pac_config) do
    outputs = [
      "Composed a short piece of writing",
      "Designed a conceptual framework",
      "Created a visual representation",
      "Developed a novel solution approach",
      "Synthesized ideas in a new way"
    ]

    Enum.random(outputs)
  end

  defp generate_learning_outcome(pac_config) do
    outcomes = [
      "Mastered a new concept",
      "Developed deeper understanding",
      "Connected disparate ideas",
      "Acquired practical skills",
      "Gained theoretical knowledge"
    ]

    Enum.random(outcomes)
  end

  defp calculate_tool_energy_cost(tool_name, tool_inputs) do
    base_costs = %{
      "memory_search" => 5,
      "communicate" => 8,
      "observe" => 3
    }

    base_cost = Map.get(base_costs, tool_name, 10)

    # Add complexity modifier based on input size
    complexity_modifier =
      tool_inputs
      |> Map.values()
      |> Enum.reduce(0, fn
        val, acc when is_binary(val) -> acc + div(String.length(val), 100)
        val, acc when is_list(val) -> acc + length(val)
        _, acc -> acc + 1
      end)

    max(base_cost + complexity_modifier, 1)
  end
end
