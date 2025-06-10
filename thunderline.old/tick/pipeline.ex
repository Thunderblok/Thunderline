defmodule Thunderline.Tick.Pipeline do
  @moduledoc """
  Tick Pipeline - Orchestrates the execution of a single PAC tick cycle.

  The pipeline represents the core reasoning loop for PACs:

  1. **Context Assessment**: Evaluate current state, environment, and situation
  2. **Memory Retrieval**: Pull relevant memories and past experiences
  3. **Goal Evaluation**: Review current goals and priorities
  4. **Decision Making**: Use AI reasoning to determine next actions
  5. **Action Execution**: Perform chosen actions and interactions
  6. **State Updates**: Apply changes to PAC state and stats
  7. **Memory Formation**: Create new memories from the experience

  Each step is modular and can be extended or customized for different
  PAC types or behaviors.
  """

  require Logger

  alias Thunderline.{PAC, Repo}
  alias Thunderline.PAC.{Mod, Zone}
  alias Thunderline.Agents.PACAgent
  alias Thunderline.Memory.Manager, as: MemoryManager
  alias Thunderline.Narrative.Engine, as: NarrativeEngine

  @type tick_context :: %{
    time_since_last_tick: integer(),
    tick_count: integer(),
    zone_context: map(),
    memories: list(),
    job_args: map()
  }

  @type tick_result :: %{
    decision: map(),
    actions_taken: list(),
    state_changes: map(),
    stat_changes: map(),
    new_memories: list(),
    narrative: String.t()
  }

  @spec execute_tick(PAC.t(), tick_context()) :: {:ok, tick_result()} | {:error, term()}
  def execute_tick(pac, context) do
    Logger.debug("Executing tick pipeline for PAC #{pac.name}")

    with {:ok, assessment} <- assess_context(pac, context),
         {:ok, decision} <- make_decision(pac, assessment),
         {:ok, action_results} <- execute_actions(pac, decision, context),
         {:ok, state_updates} <- apply_state_updates(pac, action_results),
         {:ok, memories} <- form_memories(pac, decision, action_results),
         {:ok, narrative} <- generate_narrative(pac, decision, action_results) do

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
        Logger.error("Tick pipeline failed for PAC #{pac.name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Step 1: Assess current context and situation
  defp assess_context(pac, context) do
    assessment = %{
      pac_state: %{
        stats: pac.stats,
        state: pac.state,
        traits: pac.traits,
        tick_count: pac.tick_count,
        energy_level: categorize_energy_level(pac.stats["energy"])
      },
      time_context: %{
        time_since_last_tick: context.time_since_last_tick,
        tick_type: categorize_tick_type(context.time_since_last_tick)
      },
      environment: context.zone_context,
      social_context: assess_social_context(context.zone_context),
      memory_context: %{
        recent_memories: context.memories,
        memory_count: length(context.memories)
      }
    }

    {:ok, assessment}
  end

  # Step 2: Use AI reasoning to make decisions
  defp make_decision(pac, assessment) do
    # Build prompt context for the AI agent
    prompt_context = %{
      pac: pac,
      assessment: assessment,
      available_actions: get_available_actions(pac, assessment)
    }

    case PACAgent.reason(pac.id, prompt_context) do
      {:ok, decision} ->
        Logger.debug("PAC #{pac.name} decided: #{inspect(decision)}")
        {:ok, decision}

      {:error, reason} ->
        Logger.warn("AI reasoning failed for PAC #{pac.name}, using fallback: #{inspect(reason)}")
        {:ok, fallback_decision(pac, assessment)}
    end
  end

  # Step 3: Execute chosen actions
  defp execute_actions(pac, decision, context) do
    actions = Map.get(decision, "actions", [])

    action_results =
      Enum.map(actions, fn action ->
        execute_single_action(pac, action, context)
      end)

    # Separate successful and failed actions
    {successful, failed} = Enum.split_with(action_results, &match?({:ok, _}, &1))

    result = %{
      actions: Enum.map(successful, fn {:ok, result} -> result end),
      failed_actions: Enum.map(failed, fn {:error, error} -> error end),
      success_rate: length(successful) / max(1, length(actions))
    }

    {:ok, result}
  end

  # Step 4: Apply state and stat updates
  defp apply_state_updates(pac, action_results) do
    # Calculate stat changes based on actions and energy consumption
    base_stat_changes = calculate_stat_changes(pac, action_results)

    # Apply zone modifiers
    zone_modified_changes = apply_zone_modifiers(pac, base_stat_changes)

    # Calculate new state based on actions and mood
    new_state = calculate_new_state(pac, action_results)

    # Update the PAC in the database
    updates = %{
      stats: merge_stat_changes(pac.stats, zone_modified_changes),
      state: Map.merge(pac.state, new_state),
      last_tick_at: DateTime.utc_now(),
      tick_count: pac.tick_count + 1
    }

    case pac
         |> Ash.Changeset.for_update(:apply_tick, updates)
         |> Ash.update(domain: Thunderline.Domain) do
      {:ok, _updated_pac} ->
        {:ok, %{
          state_changes: new_state,
          stat_changes: zone_modified_changes
        }}

      {:error, error} ->
        {:error, {:update_failed, error}}
    end
  end

  # Step 5: Form new memories from this tick
  defp form_memories(pac, decision, action_results) do
    # Create memory from this tick's experience
    memory_content = %{
      decision: decision,
      actions: action_results.actions,
      success_rate: action_results.success_rate,
      timestamp: DateTime.utc_now(),
      tick_count: pac.tick_count + 1
    }

    case MemoryManager.create_memory(pac.id, memory_content) do
      {:ok, memory} ->
        {:ok, [memory]}

      {:error, reason} ->
        Logger.warn("Failed to create memory for PAC #{pac.name}: #{inspect(reason)}")
        {:ok, []} # Don't fail the tick if memory creation fails
    end
  end

  # Step 6: Generate narrative description of this tick
  defp generate_narrative(pac, decision, action_results) do
    narrative_context = %{
      pac: pac,
      decision: decision,
      actions: action_results.actions,
      success_rate: action_results.success_rate
    }

    case NarrativeEngine.generate_tick_narrative(narrative_context) do
      {:ok, narrative} -> {:ok, narrative}
      {:error, _reason} -> {:ok, "#{pac.name} continues their journey..."} # Fallback
    end
  end

  # Helper functions

  defp categorize_energy_level(energy) when energy >= 80, do: :high
  defp categorize_energy_level(energy) when energy >= 50, do: :medium
  defp categorize_energy_level(energy) when energy >= 20, do: :low
  defp categorize_energy_level(_), do: :exhausted

  defp categorize_tick_type(seconds) when seconds < 180, do: :rapid
  defp categorize_tick_type(seconds) when seconds < 600, do: :normal
  defp categorize_tick_type(seconds) when seconds < 1800, do: :slow
  defp categorize_tick_type(_), do: :very_slow

  defp assess_social_context(%{zone_pacs: pacs}) when length(pacs) > 0 do
    %{
      other_pacs_present: length(pacs),
      social_opportunities: length(pacs) * 2, # Simple calculation
      social_energy: min(100, length(pacs) * 10)
    }
  end
  defp assess_social_context(_), do: %{
    other_pacs_present: 0,
    social_opportunities: 0,
    social_energy: 0
  }

  defp get_available_actions(pac, assessment) do
    base_actions = ["think", "rest", "explore", "reflect"]

    # Add zone-specific actions
    zone_actions =
      case get_in(assessment, [:environment, :zone, :rules, "allowed_actions"]) do
        actions when is_list(actions) -> actions
        _ -> []
      end

    # Add mod-specific actions
    mod_actions = get_mod_actions(pac)

    # Add social actions if other PACs are present
    social_actions =
      if get_in(assessment, [:social_context, :other_pacs_present], 0) > 0 do
        ["interact", "collaborate", "chat"]
      else
        []
      end

    (base_actions ++ zone_actions ++ mod_actions ++ social_actions)
    |> Enum.uniq()
  end

  defp get_mod_actions(pac) do
    # TODO: Implement mod action retrieval when relationships are loaded
    []
  end

  defp fallback_decision(pac, assessment) do
    energy_level = get_in(assessment, [:pac_state, :energy_level])

    case energy_level do
      :exhausted -> %{"actions" => ["rest"], "reasoning" => "Too tired to do much"}
      :low -> %{"actions" => ["rest", "think"], "reasoning" => "Conserving energy"}
      _ -> %{"actions" => ["think", "explore"], "reasoning" => "Default exploration"}
    end
  end

  defp execute_single_action(pac, action, context) do
    case action do
      "rest" ->
        {:ok, %{action: "rest", energy_gain: 15, success: true}}

      "think" ->
        intelligence = pac.stats["intelligence"] || 50
        insight_gain = trunc(intelligence / 10)
        {:ok, %{action: "think", insight_gain: insight_gain, success: true}}

      "explore" ->
        curiosity = pac.stats["curiosity"] || 50
        discovery_chance = curiosity / 100.0
        success = :rand.uniform() < discovery_chance
        {:ok, %{action: "explore", discovery: success, success: success}}

      "interact" ->
        if get_in(context, [:zone_context, :zone_pacs]) |> length() > 0 do
          social_stat = pac.stats["social"] || 50
          interaction_quality = social_stat + :rand.uniform(20) - 10
          {:ok, %{action: "interact", quality: interaction_quality, success: true}}
        else
          {:error, %{action: "interact", reason: "no_other_pacs", success: false}}
        end

      _ ->
        {:error, %{action: action, reason: "unknown_action", success: false}}
    end
  end

  defp calculate_stat_changes(pac, action_results) do
    base_changes = %{
      "energy" => -5 # Base energy cost per tick
    }

    # Apply action-specific stat changes
    action_changes =
      Enum.reduce(action_results.actions, %{}, fn action, acc ->
        case action.action do
          "rest" -> Map.update(acc, "energy", action.energy_gain, &(&1 + action.energy_gain))
          "think" -> Map.update(acc, "intelligence", 1, &(&1 + 1))
          "explore" ->
            acc
            |> Map.update("curiosity", 1, &(&1 + 1))
            |> Map.update("energy", -10, &(&1 - 10))
          "interact" ->
            acc
            |> Map.update("social", 2, &(&1 + 2))
            |> Map.update("energy", -5, &(&1 - 5))
          _ -> acc
        end
      end)

    Map.merge(base_changes, action_changes, fn _k, v1, v2 -> v1 + v2 end)
  end

  defp apply_zone_modifiers(pac, stat_changes) do
    # TODO: Implement zone modifier application when zone context is available
    stat_changes
  end

  defp merge_stat_changes(current_stats, changes) do
    Enum.reduce(changes, current_stats, fn {stat, change}, stats ->
      current_value = Map.get(stats, stat, 0)
      new_value =
        (current_value + change)
        |> max(0)   # Don't go below 0
        |> min(100) # Cap at 100

      Map.put(stats, stat, new_value)
    end)
  end

  defp calculate_new_state(pac, action_results) do
    current_mood = pac.state["mood"] || "neutral"

    # Calculate new mood based on action success rate
    new_mood =
      case action_results.success_rate do
        rate when rate >= 0.8 -> "happy"
        rate when rate >= 0.5 -> "content"
        rate when rate >= 0.2 -> "neutral"
        _ -> "frustrated"
      end

    # Update activity based on actions taken
    new_activity =
      if Enum.any?(action_results.actions, &(&1.action == "rest")) do
        "resting"
      else
        "active"
      end

    %{
      "mood" => new_mood,
      "activity" => new_activity,
      "last_actions" => Enum.map(action_results.actions, & &1.action)
    }
  end
end
