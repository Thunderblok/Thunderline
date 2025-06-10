defmodule Thunderline.Tick.Pipeline do
  @moduledoc """
  Tick Pipeline - Orchestrates the execution of a single PAC Agent tick cycle.

  The pipeline represents the core reasoning loop for PAC Agents:

  1. **Context Assessment**: Evaluate current state, environment, and situation
  2. **Memory Retrieval**: Pull relevant memories and past experiences
  3. **Goal Evaluation**: Review current goals and priorities
  4. **Decision Making**: Use AI reasoning to determine next actions
  5. **Action Execution**: Perform chosen actions and interactions
  6. **State Updates**: Apply changes to PAC Agent state and stats
  7. **Memory Formation**: Create new memories from the experience

  Each step is modular and can be extended or customized for different
  PAC Agent types or behaviors.
  """

  require Logger

  alias Thunderline.PAC.{Agent, Mod, Zone}
  alias Thunderline.Agents.PACAgent
  alias Thunderline.Memory.Manager, as: MemoryManager
  alias Thunderline.Narrative.Engine, as: NarrativeEngine

  @type tick_context :: %{
    agent_id: String.t(),
    time_since_last_tick: integer(),
    tick_number: integer(),
    environment: map(),
    memory: map(),
    modifications: map(),
    timestamp: DateTime.t()
  }

  @type tick_result :: %{
    decision: map(),
    actions_taken: list(),
    state_changes: map(),
    stat_changes: map(),
    new_memories: list(),
    narrative: String.t()
  }

  @spec execute_tick(Agent.t(), tick_context()) :: {:ok, tick_result()} | {:error, term()}
  def execute_tick(agent, context) do
    Logger.debug("Executing tick pipeline for PAC Agent #{agent.name}")

    with {:ok, assessment} <- assess_context(agent, context),
         {:ok, decision} <- make_decision(agent, assessment),
         {:ok, action_results} <- execute_actions(agent, decision, context),
         {:ok, state_updates} <- apply_state_updates(agent, action_results),
         {:ok, memories} <- form_memories(agent, decision, action_results),
         {:ok, narrative} <- generate_narrative(agent, decision, action_results) do

      result = %{
        decision: decision,
        actions_taken: action_results.actions,
        state_changes: state_updates.state_changes,
        stat_changes: state_updates.stat_changes,
        new_memories: memories,
        narrative: narrative
      }

      {:ok, result}
    else
      {:error, reason} ->
        Logger.error("Tick pipeline failed for PAC Agent #{agent.name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Step 1: Assess current context and situation
  defp assess_context(agent, context) do
    assessment = %{
      agent_state: %{
        stats: agent.stats,
        state: agent.state,
        traits: agent.traits,
        energy_level: categorize_energy_level(Map.get(agent.stats, "energy", 50))
      },
      time_context: %{
        time_since_last_tick: context.time_since_last_tick,
        tick_type: categorize_tick_type(context.time_since_last_tick)
      },
      environment: context.environment,
      social_context: assess_social_context(context.environment),
      memory_context: context.memory,
      modifications: context.modifications
    }

    {:ok, assessment}
  end

  # Step 2: Use AI reasoning to make decisions
  defp make_decision(agent, assessment) do
    # Build prompt context for the AI agent
    prompt_context = %{
      agent_name: agent.name,
      agent_description: agent.description,
      current_stats: assessment.agent_state.stats,
      current_state: assessment.agent_state.state,
      personality_traits: assessment.agent_state.traits,
      environment: assessment.environment,
      recent_memories: assessment.memory_context.recent_memories,
      time_context: assessment.time_context,
      active_modifications: assessment.modifications
    }

    # Use PACAgent (Jido AI Agent) to make decision
    case PACAgent.make_decision(agent.id, prompt_context) do
      {:ok, decision} ->
        Logger.debug("AI decision made for #{agent.name}: #{inspect(decision.action_type)}")
        {:ok, decision}

      {:error, reason} ->
        Logger.error("AI decision failed for #{agent.name}: #{inspect(reason)}")
        # Fallback to basic decision
        fallback_decision = create_fallback_decision(agent, assessment)
        {:ok, fallback_decision}
    end
  end

  # Step 3: Execute chosen actions
  defp execute_actions(agent, decision, context) do
    actions = []
    results = []

    # Execute primary action
    case execute_primary_action(agent, decision, context) do
      {:ok, primary_result} ->
        actions = [decision.action_type | actions]
        results = [primary_result | results]

        # Execute any secondary actions
        secondary_results = execute_secondary_actions(agent, decision, context)

        action_results = %{
          actions: actions ++ Map.get(decision, :secondary_actions, []),
          results: results ++ secondary_results,
          success: true
        }

        {:ok, action_results}

      {:error, reason} ->
        Logger.warning("Primary action failed for #{agent.name}: #{inspect(reason)}")

        action_results = %{
          actions: [decision.action_type],
          results: [{:error, reason}],
          success: false
        }

        {:ok, action_results}
    end
  end

  # Step 4: Apply state and stat updates
  defp apply_state_updates(agent, action_results) do
    # Calculate state changes based on actions taken
    state_changes = calculate_state_changes(agent, action_results)
    stat_changes = calculate_stat_changes(agent, action_results)

    # Apply changes to agent
    case Agent.tick(agent) do
      {:ok, updated_agent} ->
        # Apply additional changes if needed
        additional_updates = %{
          state: Map.merge(agent.state, state_changes),
          stats: Map.merge(agent.stats, stat_changes)
        }

        case Agent.update(updated_agent, additional_updates) do
          {:ok, _final_agent} ->
            {:ok, %{state_changes: state_changes, stat_changes: stat_changes}}

          {:error, reason} ->
            {:error, {:state_update_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:tick_update_failed, reason}}
    end
  end

  # Step 5: Form new memories
  defp form_memories(agent, decision, action_results) do
    memories = []

    # Create memory of the decision made
    decision_memory = %{
      content: "I decided to #{decision.action_type} because #{Map.get(decision, :reasoning, "it seemed appropriate")}",
      tags: ["decision", "tick", decision.action_type],
      importance: calculate_decision_importance(decision),
      memory_type: :episodic
    }

    # Create memories of action results
    action_memories = Enum.map(action_results.results, fn result ->
      case result do
        {:ok, outcome} ->
          %{
            content: "My action resulted in: #{inspect(outcome)}",
            tags: ["action", "result", "success"],
            importance: 0.6,
            memory_type: :episodic
          }

        {:error, reason} ->
          %{
            content: "My action failed: #{inspect(reason)}",
            tags: ["action", "result", "failure"],
            importance: 0.8,  # Failures are more important to remember
            memory_type: :episodic
          }
      end
    end)

    all_memories = [decision_memory | action_memories]

    # Store memories via Memory Manager
    stored_memories = Enum.map(all_memories, fn memory ->
      case MemoryManager.store(agent.id, memory.content,
                               tags: memory.tags,
                               importance: memory.importance,
                               memory_type: memory.memory_type) do
        {:ok, memory_node} -> memory_node
        {:error, _reason} -> nil
      end
    end)
    |> Enum.filter(& &1 != nil)

    {:ok, stored_memories}
  end

  # Step 6: Generate narrative
  defp generate_narrative(agent, decision, action_results) do
    narrative_context = %{
      agent_name: agent.name,
      decision: decision,
      actions: action_results.actions,
      success: action_results.success
    }

    case NarrativeEngine.generate_tick_narrative(narrative_context) do
      {:ok, narrative} -> {:ok, narrative}
      {:error, _reason} ->
        # Fallback narrative
        fallback = create_fallback_narrative(agent, decision, action_results)
        {:ok, fallback}
    end
  end

  # Helper functions

  defp categorize_energy_level(energy) when energy > 80, do: :high
  defp categorize_energy_level(energy) when energy > 40, do: :moderate
  defp categorize_energy_level(_energy), do: :low

  defp categorize_tick_type(time_delta) when time_delta < 60, do: :rapid
  defp categorize_tick_type(time_delta) when time_delta < 300, do: :normal
  defp categorize_tick_type(_time_delta), do: :slow

  defp assess_social_context(environment) do
    case Map.get(environment, :zone_agents, []) do
      [] -> %{social_density: :isolated, nearby_agents: []}
      agents when length(agents) < 5 -> %{social_density: :sparse, nearby_agents: agents}
      agents -> %{social_density: :crowded, nearby_agents: Enum.take(agents, 5)}
    end
  end

  defp execute_primary_action(agent, decision, _context) do
    # This would integrate with actual action systems
    # For now, simulate action execution
    case decision.action_type do
      :explore -> {:ok, %{outcome: "explored_area", discovery: "interesting_location"}}
      :rest -> {:ok, %{outcome: "energy_recovered", amount: 10}}
      :interact -> {:ok, %{outcome: "social_interaction", with: "nearby_agent"}}
      :learn -> {:ok, %{outcome: "knowledge_gained", topic: "environment"}}
      _ -> {:ok, %{outcome: "basic_action", result: "completed"}}
    end
  end

  defp execute_secondary_actions(_agent, _decision, _context) do
    # Execute any secondary actions
    []
  end

  defp calculate_state_changes(_agent, action_results) do
    # Calculate how actions affect agent state
    base_changes = %{
      "last_action" => List.first(action_results.actions, :none),
      "activity" => if(action_results.success, do: "active", else: "frustrated")
    }

    # Add action-specific state changes
    case List.first(action_results.actions) do
      :rest -> Map.put(base_changes, "mood", "refreshed")
      :explore -> Map.put(base_changes, "current_focus", "exploration")
      :interact -> Map.put(base_changes, "mood", "social")
      _ -> base_changes
    end
  end

  defp calculate_stat_changes(_agent, action_results) do
    # Calculate how actions affect agent stats
    base_changes = %{}

    case List.first(action_results.actions) do
      :rest -> %{"energy" => 15}
      :explore -> %{"energy" => -5, "exploration" => 2}
      :interact -> %{"energy" => -3, "social" => 2}
      :learn -> %{"energy" => -8, "focus" => 3}
      _ -> %{"energy" => -2}  # Default energy cost
    end
  end

  defp calculate_decision_importance(decision) do
    # More complex decisions are more important to remember
    case decision.action_type do
      :major_decision -> 0.9
      :interact -> 0.7
      :explore -> 0.6
      :learn -> 0.8
      _ -> 0.5
    end
  end

  defp create_fallback_decision(agent, assessment) do
    # Create a basic decision when AI fails
    energy_level = assessment.agent_state.energy_level

    action_type = case energy_level do
      :low -> :rest
      :moderate -> :explore
      :high -> :interact
    end

    %{
      action_type: action_type,
      reasoning: "Fallback decision based on energy level: #{energy_level}",
      confidence: 0.3,
      secondary_actions: []
    }
  end

  defp create_fallback_narrative(agent, decision, action_results) do
    action = List.first(action_results.actions, "unknown")
    success_text = if action_results.success, do: "successfully", else: "unsuccessfully"

    "#{agent.name} #{success_text} attempted to #{action}. They decided to #{decision.action_type} based on their current situation."
  end
end
