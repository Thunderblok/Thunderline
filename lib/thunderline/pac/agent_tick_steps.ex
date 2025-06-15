defmodule Thunderline.PAC.AgentTickSteps do
  @moduledoc """
  Reactor step implementations for PAC Agent tick processing.

  Contains individual step functions that can be called by the Reactor pipeline.
  Enhanced with Graphmath-powered zone movement validation.
  """

  use Reactor.Step
  require Logger

  # Import zone and grid system for movement validation
  alias Thunderline.World.{Zone, Grid}
  alias Thunderline.PAC.Agent
  @impl true
  def run(arguments, context, step_options) do
    step_name = Map.get(arguments, :step_name) || Map.get(step_options, :step_name, :unknown)

    case step_name do
      :context_assessment -> assess_context(arguments, context)
      :decision_making -> make_decision(arguments, context)
      :action_execution -> execute_action(arguments, context)
      :memory_formation -> form_memory(arguments, context)
      :state_update -> update_agent_state(arguments, context)
      _ -> {:error, "Unknown step: #{step_name}"}
    end
  end

  def assess_context(%{agent: agent}, _context) do
    # For now, use simple context assessment logic until Ash AI prompt actions are fully configured
    current_stats = agent.stats || %{}
    energy = Map.get(current_stats, "energy", 50)

    emotional_state = cond do
      energy > 70 -> "energetic"
      energy > 40 -> "content"
      energy > 15 -> "tired"
      true -> "exhausted"
    end

    motivations = case emotional_state do
      "energetic" -> ["explore", "socialize", "accomplish_goals"]
      "content" -> ["maintain_status", "gentle_activities"]
      "tired" -> ["rest", "low_energy_activities"]
      "exhausted" -> ["rest", "recover"]
    end

    priorities = if energy < 30, do: ["rest"], else: ["maintain_energy", "interact"]

    {:ok, %{
      summary: "Agent is currently #{emotional_state} with #{energy} energy",
      emotional_state: emotional_state,
      motivations: motivations,
      priorities: priorities,
      environmental_factors: %{zone_id: agent.zone_id},
      confidence_level: 0.8
    }}
  end

  def make_decision(%{context: context, agent: agent}, _reactor_context) do
    # Simple decision making based on context priorities
    %{emotional_state: emotional_state, priorities: priorities} = context

    chosen_action = cond do
      "rest" in priorities -> "rest"
      emotional_state == "energetic" -> Enum.random(["explore", "socialize"])
      true -> "idle"
    end

    action_params = case chosen_action do
      "rest" -> %{duration: "short"}
      "explore" -> %{direction: Enum.random(["north", "south", "east", "west"])}
      "socialize" -> %{interaction_type: "friendly_chat"}
      _ -> %{}
    end

    {:ok, %{
      chosen_action: chosen_action,
      action_params: action_params,
      reasoning: "Based on #{emotional_state} state and priorities: #{inspect(priorities)}",
      confidence: 0.7
    }}
  end
  def execute_action(%{decision: decision, agent: agent}, _context) do
    %{chosen_action: action, action_params: params} = decision

    case action do
      "rest" ->
        Thunderline.AI.Tools.Rest.rest(params, %{agent: agent})

      "explore" ->
        # Enhanced exploration with zone movement validation
        explore_params = Map.put_new(params, :direction, "north")

        # Validate movement if agent wants to explore to a new zone
        case validate_movement(agent, explore_params) do
          {:ok, movement_result} ->
            # Execute exploration with movement
            case Thunderline.AI.Tools.Explore.explore(explore_params, %{agent: agent}) do
              {:ok, explore_result} ->
                # Merge movement and exploration results
                {:ok, Map.merge(explore_result, movement_result)}

              explore_error ->
                explore_error
            end

          {:error, movement_error} ->
            # Movement not possible, still explore current area
            case Thunderline.AI.Tools.Explore.explore(Map.put(explore_params, :intensity, "cautious"), %{agent: agent}) do
              {:ok, explore_result} ->
                {:ok, Map.put(explore_result, :movement_blocked, movement_error)}

              explore_error ->
                explore_error
            end
        end

      "socialize" ->
        social_params = Map.put_new(params, :interaction_type, "chat")
        Thunderline.AI.Tools.Socialize.socialize(social_params, %{agent: agent})

      "idle" ->
        {:ok, %{
          result_message: "Agent spent time in quiet contemplation",
          energy_change: 0,
          outcome: "peaceful reflection"
        }}

      _ ->
        {:error, "Unknown action: #{action}"}
    end
  end

  def form_memory(%{context: context, decision: decision, action_result: action_result, agent: agent}, _reactor_context) do
    # Simple memory formation logic for now
    %{chosen_action: action, reasoning: reasoning} = decision

    memory_content = case action_result do
      {:ok, result} ->
        outcome = Map.get(result, :result_message, "completed action")
        "Agent decided to #{action} because #{reasoning}. Result: #{outcome}"

      {:error, error} ->
        "Agent attempted to #{action} but encountered an error: #{inspect(error)}"

      result when is_map(result) ->
        outcome = Map.get(result, :result_message, "completed action")
        "Agent decided to #{action} because #{reasoning}. Result: #{outcome}"

      _ ->
        "Agent performed #{action} with unknown outcome"
    end

    # Calculate emotional impact
    emotional_impact = case action do
      "rest" -> "positive"
      "explore" -> "curious"
      "socialize" -> "social"
      _ -> "neutral"
    end

    # Determine importance score
    importance_score = case action do
      "rest" when context.emotional_state == "exhausted" -> 0.9
      "explore" -> 0.6
      "socialize" -> 0.7
      _ -> 0.4
    end

    {:ok, %{
      memory_content: memory_content,
      emotional_impact: emotional_impact,
      importance_score: importance_score,
      memory_tags: [action, context.emotional_state],
      context_snapshot: %{
        energy_before: Map.get(agent.stats || %{}, "energy", 50),
        emotional_state: context.emotional_state
      }
    }}
  end

  def update_agent_state(%{agent: agent, action_result: action_result, memory_formed: memory}, _context) do
    # Extract action result data (handle both {:ok, result} and direct result formats)
    result_data = case action_result do
      {:ok, data} -> data
      {:error, _} = error -> %{result_message: "Action failed: #{inspect(error)}", energy_change: 0}
      data when is_map(data) -> data
      _ -> %{result_message: "Unknown result", energy_change: 0}
    end

    # Calculate new stats based on action result
    current_stats = agent.stats || %{}
    energy_change = Map.get(result_data, :energy_change, 0)
    energy_gained = Map.get(result_data, :energy_gained, 0)

    new_energy = current_stats
                 |> Map.get("energy", 50)
                 |> Kernel.+(energy_change + energy_gained)
                 |> max(0)
                 |> min(100)

    new_stats = Map.put(current_stats, "energy", new_energy)

    # Update agent state
    current_state = agent.state || %{}
    new_activity = case Map.get(result_data, :result_message, "") do
      msg when is_binary(msg) and msg != "" -> "recently_active"
      _ -> "idle"
    end

    new_state = Map.put(current_state, "activity", new_activity)

    # Store the formed memory in the actual memory system
    store_memory_result = case memory do
      %{memory_content: content} when is_binary(content) ->
        Thunderline.Memory.Manager.store_memory(content, agent.id, %{
          tags: Map.get(memory, :memory_tags, []),
          importance: Map.get(memory, :importance_score, 0.5),
          context: %{
            action: Map.get(result_data, :result_message, ""),
            emotional_impact: Map.get(memory, :emotional_impact, "neutral")
          }
        })
      _ ->
        {:ok, nil}
    end

    # Update the agent with new stats and state
    case Thunderline.PAC.Agent.update(agent, %{stats: new_stats, state: new_state}, domain: Thunderline.Domain) do
      {:ok, updated_agent} ->
        {:ok, %{
          agent: updated_agent,
          action_result: result_data,
          memory_stored: store_memory_result,
          stats_change: %{energy: new_energy - Map.get(current_stats, "energy", 50)},
          state_change: %{activity: new_activity}
        }}

      {:error, error} ->
        {:error, error}
    end
  end

  # Enhanced movement validation using Graphmath and Zone system
  defp validate_movement(agent, explore_params) do
    direction = Map.get(explore_params, :direction, "north")
    move_range = Map.get(explore_params, :distance, 1.0)

    # Get current zone coordinates if available
    current_coords = get_agent_coordinates(agent)

    # Calculate target coordinates based on direction
    target_coords = calculate_target_coordinates(current_coords, direction, move_range)

    # Validate movement using Graphmath
    case Thunderline.World.Grid.can_move?(current_coords, target_coords, move_range) do
      true ->
        # Check if target zone exists and is accessible
        case get_target_zone(target_coords) do
          {:ok, target_zone} ->
            if zone_accessible?(target_zone) do
              {:ok, %{
                movement_allowed: true,
                from_coords: current_coords,
                to_coords: target_coords,
                target_zone: target_zone.id,
                distance: Thunderline.World.Grid.distance(current_coords, target_coords)
              }}
            else
              {:error, "Target zone is not accessible"}
            end

          {:error, reason} ->
            {:error, "No valid zone at target coordinates: #{reason}"}
        end

      false ->
        {:error, "Movement distance exceeds agent's range (#{move_range})"}
    end
  end

  # Get agent's current coordinates (from zone or default)
  defp get_agent_coordinates(agent) do
    # Try to get coordinates from agent's current zone
    case agent.zone_id do
      nil ->
        # Default starting coordinates
        %{"x" => 0, "y" => 0, "z" => 0}

      zone_id ->
        case Thunderline.World.Zone.by_coords(%{"x" => 0, "y" => 0, "z" => 0}) do
          {:ok, [zone | _]} -> zone.coords
          _ -> %{"x" => 0, "y" => 0, "z" => 0}
        end
    end
  end

  # Calculate target coordinates based on direction and distance
  defp calculate_target_coordinates(current_coords, direction, distance) do
    x = Map.get(current_coords, "x", 0)
    y = Map.get(current_coords, "y", 0)
    z = Map.get(current_coords, "z", 0)

    case direction do
      "north" -> %{"x" => x, "y" => y + round(distance), "z" => z}
      "south" -> %{"x" => x, "y" => y - round(distance), "z" => z}
      "east" -> %{"x" => x + round(distance), "y" => y, "z" => z}
      "west" -> %{"x" => x - round(distance), "y" => y, "z" => z}
      "up" -> %{"x" => x, "y" => y, "z" => z + round(distance)}
      "down" -> %{"x" => x, "y" => y, "z" => z - round(distance)}
      _ -> current_coords  # Unknown direction, stay in place
    end
  end

  # Find zone at target coordinates
  defp get_target_zone(coords) do
    case Thunderline.World.Zone.by_coords(coords) do
      {:ok, [zone | _]} -> {:ok, zone}
      {:ok, []} -> {:error, "No zone found"}
      {:error, reason} -> {:error, reason}
    end
  end

  # Check if zone is accessible
  defp zone_accessible?(zone) do
    accessibility = Decimal.to_float(zone.accessibility || Decimal.new("1.0"))
    accessibility > 0.5  # Zone must be at least 50% accessible
  end
end
