defmodule Thunderline.AgentCore.ActionExecutor do
  @moduledoc """
  Executes a decision and returns updated PAC state (pac_config) and outcome.
  Handles action planning, execution via specific handlers, and state updates.
  """

  require Logger
  # ToolRegistry might not be used directly here if ToolRouter handles all.
  alias Thunderline.MCP.{ToolRouter, ToolRegistry}
  alias Thunderline.PAC.Manager

  # %{action: String.t(), confidence: float(), reasoning: String.t(), ...}
  @type decision_map :: map()
  # %{pac_id: String.t(), pac_name: String.t(), stats: map(), traits: list(String.t())}
  @type pac_config_map :: map()
  # %{zone_context: map(), ...}
  @type context_map :: map()
  @type available_tools_list :: list(String.t())
  @type action_plan :: map()
  @type execution_outcome :: map()
  @type state_updates_map :: map()
  @type metadata_map :: map()

  @spec run(decision_map(), pac_config_map(), context_map(), available_tools_list()) ::
          {:ok, {pac_config_map(), execution_outcome(), metadata_map()}} | {:error, any()}
  def run(decision, pac_config, context, available_tools) do
    action = Map.get(decision, :action, "unknown_action")

    # Pass pac_config for richer plans
    with {:ok, plan} <- create_action_plan(action, decision, context, pac_config),
         {:ok, outcome} <- execute_action_plan(plan, pac_config, available_tools),
         {:ok, state_updates} <- calculate_state_updates(outcome, pac_config),
         {:ok, _applied_marker} <- apply_state_updates(pac_config.pac_id, state_updates) do
      updated_pac_config =
        Map.merge(pac_config, %{
          "stats" => Map.merge(pac_config["stats"] || %{}, state_updates["stats"] || %{}),
          "state" => Map.merge(pac_config["state"] || %{}, state_updates["state"] || %{})
        })

      metadata = %{
        timestamp: DateTime.utc_now(),
        action_plan: plan,
        raw_outcome: outcome,
        state_changes_applied: state_updates
      }

      {:ok, {updated_pac_config, outcome, metadata}}
    else
      {:error, reason} ->
        Logger.error("ActionExecutor run failed: #{inspect(reason)}")
        {:error, reason}

      # Catch any other unexpected errors
      err ->
        Logger.error("ActionExecutor unexpected error: #{inspect(err)}")
        {:error, {:unexpected_executor_error, err}}
    end
  end

  # Action Planning (Adapted from Thunderline.Agents.Actions.ExecuteAction)

  # Added pac_config to create_action_plan for potentially richer context-dependent plans
  defp create_action_plan(action, decision, context, pac_config) do
    with {:ok, prerequisites} <- check_prerequisites(action, context, pac_config) do
      base_plan = %{
        action: action,
        type: classify_action_type(action),
        # decision might contain specific params for an action
        parameters: extract_action_parameters(action, decision),
        required_tools: determine_required_tools(action),
        estimated_duration: estimate_duration(action),
        # result of check_prerequisites
        prerequisites: prerequisites
      }

      {:ok, base_plan}
    else
      # Pass along error from check_prerequisites
      {:error, reason} -> {:error, reason}
    end
  end

  defp classify_action_type(action) when is_binary(action) do
    cond do
      String.starts_with?(action, "use_") -> :tool_usage
      action in ["rest", "reflect"] -> :internal
      action in ["socialize", "communicate"] -> :social
      action in ["explore", "move"] -> :movement
      action in ["create", "build", "write"] -> :creative
      action in ["learn", "study", "analyze"] -> :intellectual
      # Match prefix for specific goals
      String.starts_with?(action, "work_on_goal") -> :goal_pursuit
      true -> :general
    end
  end

  defp classify_action_type(_), do: :unknown

  defp extract_action_parameters(action, decision) do
    base_params = %{
      # The core action string
      action: action,
      # Fields from decision that might be useful for any action
      confidence: Map.get(decision, :confidence),
      reasoning: Map.get(decision, :reasoning),
      expected_outcome: Map.get(decision, :expected_outcome)
    }

    # Add action-specific parameters by inspecting the decision or action string
    # This part needs to be robust to how decision data is structured.
    # For "use_tool_X", the tool name is from the action string.
    # For "work_on_goal_Y", the goal ID/description is from the action string or decision.

    cond do
      String.starts_with?(action, "use_") ->
        tool_name = String.trim_leading(action, "use_")
        # Changed from :tool to :tool_name for clarity
        Map.put(base_params, :tool_name, tool_name)

      # Potentially extract tool-specific params if decision map contains them under a key, e.g., decision.tool_params
      String.starts_with?(action, "work_on_goal") ->
        # Example: if decision has a :goal_details map
        goal_details = Map.get(decision, :goal_details, %{})
        # Merges goal_id, description etc.
        Map.merge(base_params, goal_details)

      true ->
        base_params
    end
  end

  defp determine_required_tools(action) when is_binary(action) do
    cond do
      String.starts_with?(action, "use_") -> [String.trim_leading(action, "use_")]
      # Assuming these are abstract tools/capabilities
      action == "explore" -> ["movement", "observation"]
      action == "create" -> ["creative_tools"]
      action == "learn" -> ["learning_tools"]
      action == "socialize" -> ["communication"]
      true -> []
    end
  end

  defp determine_required_tools(_), do: []

  defp estimate_duration(action) when is_binary(action) do
    # Duration in arbitrary "ticks" or time units
    cond do
      action == "rest" -> 1
      action == "reflect" -> 2
      action == "socialize" -> 3
      action == "explore" -> 4
      action == "create" -> 5
      action == "learn" -> 4
      String.starts_with?(action, "work_on_goal") -> 6
      true -> 3
    end
  end

  defp estimate_duration(_), do: 3

  # Added pac_config for potentially checking agent's own state/stats as prerequisite
  defp check_prerequisites(action, context, pac_config) do
    # Check if action can be performed given current context and agent state
    prereqs =
      case action do
        "socialize" ->
          if (context.zone_context["pac_count"] || 0) > 1 do
            # Assuming pac_count includes self, so > 1 means others are present
            []
          else
            ["no_other_pacs_available"]
          end

        "explore" ->
          if Map.get(context.zone_context, "exploration_allowed", true) != false do
            []
          else
            ["exploration_restricted"]
          end

        "rest" ->
          if Map.get(pac_config.stats, "energy", 100) < 80, do: [], else: ["not_tired_enough"]

        _ ->
          # Default: no prerequisites or handled by tool/action itself
          []
      end

    # Return in a tuple
    {:ok, prereqs}
  end

  # Action Execution

  defp execute_action_plan(plan, pac_config, available_tools) do
    case plan.prerequisites do
      [] ->
        do_execute_action(plan, pac_config, available_tools)

      prerequisites ->
        Logger.info(
          "Action #{plan.action} cannot be executed due to unmet prerequisites: #{inspect(prerequisites)} for #{pac_config.pac_name}"
        )

        {:error, {:prerequisites_not_met, prerequisites}}
    end
  end

  defp do_execute_action(plan, pac_config, available_tools) do
    Logger.debug("Executing action: #{plan.action} for PAC #{pac_config.pac_name}")

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

      _ ->
        Logger.warning("Unknown action type: #{plan.type} for action #{plan.action}")
        {:error, {:unknown_action_type, plan.type}}
    end
  end

  # Specific Action Executors
  defp execute_tool_action(plan, pac_config, available_tools) do
    # From extract_action_parameters
    tool_name = Map.get(plan.parameters, :tool_name, "")

    if tool_name in available_tools do
      execution_context = %{
        pac_id: pac_config.pac_id,
        # zone_id, tick_count could be part of pac_config.state or context if needed by tools universally
        # agent_pid: self(), # Not applicable if this module is not a process
        metadata: %{action_type: plan.type, action_name: plan.action}
      }

      # Tool inputs should be specific, not just dropping generic fields
      tool_inputs =
        Map.get(
          plan.parameters,
          :tool_inputs,
          Map.drop(plan.parameters, [
            :action,
            :confidence,
            :reasoning,
            :expected_outcome,
            :tool_name
          ])
        )

      case ToolRouter.execute_tool(tool_name, tool_inputs, execution_context) do
        {:ok, result} ->
          {:ok,
           %{
             # Standardized outcome structure
             type: :tool_success,
             action: plan.action,
             tool_used: tool_name,
             # Tool specific result
             result: result,
             energy_cost: calculate_tool_energy_cost(tool_name, tool_inputs)
           }}

        {:error, error_type, message}
        when error_type in [:tool_not_found, :invalid_input, :execution_failed] ->
          Logger.error(
            "Tool execution failed for #{tool_name}: #{error_type} - #{inspect(message)}"
          )

          {:error, {error_type, tool_name, message}}

        # Catch other tool errors
        {:error, reason} ->
          Logger.error("Tool execution generic error for #{tool_name}: #{inspect(reason)}")
          {:error, {:tool_execution_failed, tool_name, reason}}
      end
    else
      Logger.warning(
        "Tool #{tool_name} not available for #{pac_config.pac_name}. Available: #{inspect(available_tools)}"
      )

      {:error, {:tool_not_available, tool_name}}
    end
  end

  defp execute_internal_action(plan, pac_config) do
    case plan.action do
      "rest" ->
        {:ok,
         %{
           type: :rest,
           action: plan.action,
           energy_gained: 30,
           mood_effect: "refreshed",
           description: "#{pac_config.pac_name} took time to rest and recharge"
         }}

      "reflect" ->
        {:ok,
         %{
           type: :reflection,
           action: plan.action,
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
        {:ok,
         %{
           type: :social_interaction,
           action: plan.action,
           energy_cost: 10,
           social_gain: 15,
           mood_effect: "social",
           description: "#{pac_config.pac_name} engaged in social interaction",
           interaction_type: "casual_conversation"
         }}

      # Example of another social action
      "communicate" ->
        {:ok,
         %{
           type: :communication,
           action: plan.action,
           energy_cost: 5,
           social_gain: 5,
           mood_effect: "connected",
           description: "#{pac_config.pac_name} communicated with another agent.",
           message_content: Map.get(plan.parameters, :message, "Hello!")
         }}

      _ ->
        {:error, {:unknown_social_action, plan.action}}
    end
  end

  defp execute_movement_action(plan, pac_config) do
    case plan.action do
      "explore" ->
        {:ok,
         %{
           type: :exploration,
           action: plan.action,
           energy_cost: 15,
           curiosity_satisfaction: 20,
           mood_effect: "adventurous",
           description: "#{pac_config.pac_name} explored their environment",
           discoveries: generate_exploration_discoveries(pac_config)
         }}

      # Example of another movement action
      "move" ->
        target_location = Map.get(plan.parameters, :target_location, "nearby area")

        {:ok,
         %{
           type: :movement,
           action: plan.action,
           energy_cost: 10,
           description: "#{pac_config.pac_name} moved to #{target_location}."
         }}

      _ ->
        {:error, {:unknown_movement_action, plan.action}}
    end
  end

  defp execute_creative_action(plan, pac_config) do
    case plan.action do
      # Group similar creative actions
      action when action in ["create", "build", "write"] ->
        creation = generate_creative_output(pac_config)

        {:ok,
         %{
           type: :creation,
           action: plan.action,
           energy_cost: 20,
           creativity_satisfaction: 25,
           mood_effect: "fulfilled",
           description: "#{pac_config.pac_name} engaged in creative work: #{plan.action}",
           creation: creation
         }}

      _ ->
        {:error, {:unknown_creative_action, plan.action}}
    end
  end

  defp execute_intellectual_action(plan, pac_config) do
    case plan.action do
      # Group similar intellectual actions
      action when action in ["learn", "study", "analyze"] ->
        learning = generate_learning_outcome(pac_config)

        {:ok,
         %{
           type: :learning,
           action: plan.action,
           energy_cost: 15,
           intelligence_gain: 10,
           mood_effect: "satisfied",
           description: "#{pac_config.pac_name} engaged in learning: #{plan.action}",
           learning: learning
         }}

      _ ->
        {:error, {:unknown_intellectual_action, plan.action}}
    end
  end

  defp execute_goal_action(plan, pac_config) do
    # Assumes goal_id and description are in plan.parameters from extract_action_parameters
    goal_id = Map.get(plan.parameters, :goal_id, "unknown_goal")
    goal_desc = Map.get(plan.parameters, :goal_description, "an unspecified goal")
    progress_made = Enum.random(10..30)

    {:ok,
     %{
       type: :goal_progress,
       action: plan.action,
       energy_cost: 18,
       goal_id: goal_id,
       goal_description: goal_desc,
       progress_made: progress_made,
       mood_effect: "determined",
       description: "#{pac_config.pac_name} made progress on goal: #{goal_desc}"
     }}
  end

  defp execute_general_action(plan, pac_config) do
    {:ok,
     %{
       type: :general,
       action: plan.action,
       energy_cost: 10,
       description: "#{pac_config.pac_name} performed general action: #{plan.action}"
     }}
  end

  # State Updates

  defp calculate_state_updates(execution_outcome, pac_config) do
    current_stats = Map.get(pac_config, "stats", %{})
    current_state = Map.get(pac_config, "state", %{})

    # Start with existing stats and state, override with changes
    # Default to 100 if not present
    updated_stats = Map.get(current_stats, "energy", 100)

    updated_stats =
      cond do
        cost = execution_outcome[:energy_cost] -> max(0, updated_stats - cost)
        gain = execution_outcome[:energy_gained] -> min(100, updated_stats + gain)
        true -> updated_stats
      end

    new_stats_map = Map.put(current_stats, "energy", updated_stats)
    # Pass current_stats for baseline
    new_stats_map = apply_stat_gains(new_stats_map, execution_outcome, current_stats)

    new_state_map =
      Map.merge(current_state, %{
        "activity" => execution_outcome.type || current_state["activity"] || "idle",
        "mood" => execution_outcome.mood_effect || current_state["mood"] || "neutral"
      })

    # Record last action performed
    new_state_map = Map.put(new_state_map, "last_action", execution_outcome.action)
    new_state_map = Map.put(new_state_map, "last_action_outcome", execution_outcome.type)

    final_updates = %{
      "stats" => new_stats_map,
      "state" => new_state_map
    }

    {:ok, final_updates}
  end

  defp apply_stat_gains(stats_updates_map, execution_outcome, current_stats_baseline) do
    gains = [
      {:intelligence_gain, "intelligence"},
      # Assuming this is the key in outcome
      {:creativity_gain, "creativity"},
      {:social_gain, "social"},
      # Assuming this is the key
      {:curiosity_satisfaction, "curiosity"}
    ]

    Enum.reduce(gains, stats_updates_map, fn {gain_key, stat_name}, acc ->
      if gain_value = execution_outcome[gain_key] do
        # Use baseline for current value
        current_value = Map.get(current_stats_baseline, stat_name, 50)
        new_value = min(100, current_value + gain_value)
        Map.put(acc, stat_name, new_value)
      else
        acc
      end
    end)
  end

  # pac_id is extracted from pac_config in run/4
  defp apply_state_updates(pac_id, updates) do
    # Use PAC manager to apply updates to the actual PAC record
    case Manager.update_pac_state(pac_id, updates) do
      {:ok, _updated_pac} ->
        Logger.debug("State updates applied for PAC ID #{pac_id}: #{inspect(updates)}")
        {:ok, :applied}

      {:error, reason} ->
        Logger.error("Failed to apply state updates for PAC ID #{pac_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Generation Functions (Simplified stubs, can be expanded)

  defp generate_reflection_insights(_pac_config),
    do: Enum.take_random(["Realized a pattern.", "Considered alternatives."], 1)

  defp generate_exploration_discoveries(_pac_config),
    do: Enum.take_random(["Found a new path.", "Saw something interesting."], 1)

  defp generate_creative_output(_pac_config), do: "Generated a novel idea."
  defp generate_learning_outcome(_pac_config), do: "Understood a new concept."

  defp calculate_tool_energy_cost(tool_name, tool_inputs) do
    base_costs = %{"memory_search" => 5, "communicate" => 8, "observe" => 3}
    base_cost = Map.get(base_costs, tool_name, 10)

    complexity_modifier =
      if is_map(tool_inputs) do
        tool_inputs
        |> Map.values()
        |> Enum.reduce(0, fn
          val, acc when is_binary(val) -> acc + div(String.length(val), 100)
          val, acc when is_list(val) -> acc + length(val)
          # Minimal cost for other types
          _, acc -> acc + 1
        end)
      else
        # No inputs or not a map
        0
      end

    max(base_cost + complexity_modifier, 1)
  end
end
