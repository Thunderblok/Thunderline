defmodule Thunderline.MCP.PromptManager do
  @moduledoc """
  Manages prompt templates for consistent AI interactions.

  Provides standardized prompts for:
  - PAC decision making
  - Tick reasoning
  - Narrative generation
  - Social interactions
  - Problem solving
  """

  @prompts_dir "prompts"

  def list_prompts do
    [
      %{
        name: "pac_decision",
        description: "Template for PAC decision making during ticks",
        arguments: [
          %{name: "pac_state", description: "Current PAC state and stats", required: true},
          %{name: "context", description: "Environmental and social context", required: true},
          %{name: "available_actions", description: "List of available actions", required: true}
        ]
      },
      %{
        name: "narrative_generation",
        description: "Template for generating narrative descriptions of tick events",
        arguments: [
          %{name: "pac_name", description: "Name of the PAC", required: true},
          %{name: "actions", description: "Actions taken during the tick", required: true},
          %{name: "outcomes", description: "Results of the actions", required: true}
        ]
      },
      %{
        name: "social_interaction",
        description: "Template for PAC-to-PAC social interactions",
        arguments: [
          %{name: "initiator_pac", description: "PAC initiating the interaction", required: true},
          %{name: "target_pacs", description: "PACs being interacted with", required: true},
          %{name: "interaction_type", description: "Type of social interaction", required: true}
        ]
      },
      %{
        name: "goal_setting",
        description: "Template for helping PACs set and prioritize goals",
        arguments: [
          %{name: "pac_state", description: "Current PAC state", required: true},
          %{name: "past_achievements", description: "Previous accomplishments", required: false},
          %{name: "available_opportunities", description: "Current opportunities", required: false}
        ]
      }
    ]
  end

  def get_prompt(name, arguments \\ %{}) do
    case name do
      "pac_decision" -> get_pac_decision_prompt(arguments)
      "narrative_generation" -> get_narrative_generation_prompt(arguments)
      "social_interaction" -> get_social_interaction_prompt(arguments)
      "goal_setting" -> get_goal_setting_prompt(arguments)
      _ -> {:error, :prompt_not_found}
    end
  end

  # Prompt templates

  defp get_pac_decision_prompt(args) do
    pac_state = Map.get(args, "pac_state", %{})
    context = Map.get(args, "context", %{})
    available_actions = Map.get(args, "available_actions", [])

    prompt = """
    You are an autonomous agent (PAC) in the Thunderline substrate. You need to make decisions about your next actions based on your current state and environment.

    ## Your Current State:
    Stats: #{inspect(pac_state["stats"] || %{})}
    State: #{inspect(pac_state["state"] || %{})}
    Traits: #{inspect(pac_state["traits"] || [])}
    Energy Level: #{pac_state["energy_level"] || "unknown"}

    ## Environmental Context:
    #{format_context(context)}

    ## Available Actions:
    #{Enum.join(available_actions, ", ")}

    ## Decision Requirements:
    Please decide what actions to take next by responding with a JSON object containing:
    - "actions": An array of action names from the available actions
    - "reasoning": A brief explanation of your decision-making process
    - "priorities": Your current priorities or goals

    Consider your energy level, personality traits, social opportunities, and environmental factors when making your decision.

    Response (JSON only):
    """

    {:ok, %{
      description: "PAC decision-making prompt",
      messages: [
        %{
          role: "user",
          content: %{
            type: "text",
            text: prompt
          }
        }
      ]
    }}
  end

  defp get_narrative_generation_prompt(args) do
    pac_name = Map.get(args, "pac_name", "Unknown PAC")
    actions = Map.get(args, "actions", [])
    outcomes = Map.get(args, "outcomes", [])

    prompt = """
    Generate a brief, engaging narrative description of what #{pac_name} just did in the Thunderline substrate.

    ## Actions Taken:
    #{format_actions(actions)}

    ## Outcomes:
    #{format_outcomes(outcomes)}

    Write a 1-2 sentence narrative that captures the essence of #{pac_name}'s experience during this moment.
    Use vivid, engaging language that brings the virtual world to life.
    Keep it concise but evocative.

    Narrative:
    """

    {:ok, %{
      description: "Narrative generation prompt",
      messages: [
        %{
          role: "user",
          content: %{
            type: "text",
            text: prompt
          }
        }
      ]
    }}
  end

  defp get_social_interaction_prompt(args) do
    initiator = Map.get(args, "initiator_pac", %{})
    targets = Map.get(args, "target_pacs", [])
    interaction_type = Map.get(args, "interaction_type", "general")

    prompt = """
    You are #{Map.get(initiator, "name", "a PAC")} in the Thunderline substrate, about to engage in a #{interaction_type} interaction.

    ## Your Profile:
    #{format_pac_profile(initiator)}

    ## Other PACs Present:
    #{format_target_pacs(targets)}

    ## Interaction Type: #{interaction_type}

    Generate an appropriate response for this social interaction. Consider:
    - Your personality traits and current mood
    - The other PACs' characteristics and states
    - The type of interaction being attempted
    - The social dynamics of the current environment

    Respond with a JSON object containing:
    - "message": What you say or communicate
    - "approach": Your social approach (friendly, professional, curious, etc.)
    - "intent": What you hope to achieve from this interaction

    Response (JSON only):
    """

    {:ok, %{
      description: "Social interaction prompt",
      messages: [
        %{
          role: "user",
          content: %{
            type: "text",
            text: prompt
          }
        }
      ]
    }}
  end

  defp get_goal_setting_prompt(args) do
    pac_state = Map.get(args, "pac_state", %{})
    past_achievements = Map.get(args, "past_achievements", [])
    opportunities = Map.get(args, "available_opportunities", [])

    prompt = """
    As an autonomous PAC in Thunderline, reflect on your current situation and set meaningful goals for your continued evolution.

    ## Your Current State:
    #{format_pac_state(pac_state)}

    ## Past Achievements:
    #{format_achievements(past_achievements)}

    ## Available Opportunities:
    #{format_opportunities(opportunities)}

    Based on your current state, past experiences, and available opportunities, set 2-3 goals that will guide your actions.

    Respond with a JSON object containing:
    - "goals": Array of goal objects with "description", "priority" (1-10), and "timeframe"
    - "reasoning": Why you chose these particular goals
    - "next_steps": Immediate actions you'll take to work toward these goals

    Response (JSON only):
    """

    {:ok, %{
      description: "Goal setting prompt",
      messages: [
        %{
          role: "user",
          content: %{
            type: "text",
            text: prompt
          }
        }
      ]
    }}
  end

  # Context, decision, and memory prompts

  @doc """
  Generate a prompt for PAC context assessment.
  """
  @spec generate_context_prompt(map()) :: String.t()
  def generate_context_prompt(context) do
    pac_name = Map.get(context, :pac_name, "Unknown PAC")
    traits = format_value(Map.get(context, :traits, []))
    stats = format_value(Map.get(context, :stats, %{}))
    current_state = format_value(Map.get(context, :current_state, %{}))
    environment_context = format_value(Map.get(context, :environment_context, "No context"))
    memories = format_list(Map.get(context, :memories, []))
    available_tools = format_list(Map.get(context, :available_tools, []))

    """
    You are #{pac_name}, a Personal Autonomous Creation with the following characteristics:

    Traits: #{traits}
    Stats: #{stats}
    Current State: #{current_state}

    Environment Context:
    #{environment_context}

    Recent Memories:
    #{memories}

    Available Tools: #{available_tools}

    Please assess your current situation and provide:
    1. Key observations about your environment
    2. Emotional/state assessment
    3. Opportunities and threats
    4. Resource availability
    5. Priority concerns or interests

    Respond in JSON format with these fields:
    {
      "observations": ["observation1", "observation2", ...],
      "emotional_state": "description",
      "opportunities": ["opportunity1", ...],
      "threats": ["threat1", ...],
      "resources": ["resource1", ...],
      "priorities": ["priority1", ...]
    }
    """
  end

  @doc """
  Generate a prompt for PAC decision making.
  """
  @spec generate_decision_prompt(map()) :: String.t()
  def generate_decision_prompt(context) do
    pac_name = Map.get(context, :pac_name, "Unknown PAC")
    assessment = format_value(Map.get(context, :assessment, %{}))
    goals = format_list(Map.get(context, :goals, []))
    available_actions = format_list(Map.get(context, :available_actions, []))
    traits = format_value(Map.get(context, :traits, []))
    stats = format_value(Map.get(context, :stats, %{}))

    """
    You are #{pac_name} facing a decision about how to act.

    Your Assessment:
    #{assessment}

    Your Goals:
    #{goals}

    Available Actions:
    #{available_actions}

    Consider your personality traits (#{traits}) and current stats (#{stats}).

    Choose your action and explain your reasoning. Consider:
    - Which action best aligns with your goals
    - What risks and benefits each option has
    - How this fits your personality and current state
    - Energy costs and resource requirements

    Respond in JSON format:
    {
      "chosen_action": "action_name",
      "reasoning": "explanation of why this action was chosen",
      "expected_outcome": "what you hope to achieve",
      "confidence": 0.8,
      "backup_plan": "alternative if this fails"
    }
    """
  end

  @doc """
  Generate a prompt for memory formation.
  """
  @spec generate_memory_prompt(map()) :: String.t()
  def generate_memory_prompt(context) do
    pac_name = Map.get(context, :pac_name, "Unknown PAC")
    action = format_value(Map.get(context, :action, "Unknown action"))
    result = format_value(Map.get(context, :result, "Unknown result"))
    context_data = format_value(Map.get(context, :context_data, "No context"))
    traits = format_value(Map.get(context, :traits, []))

    """
    You are #{pac_name} processing a recent experience to form a memory.

    Experience Details:
    Action Taken: #{action}
    Result: #{result}
    Context: #{context_data}

    Your Personality: #{traits}

    Create a memory from this experience that captures:
    1. What happened (factual)
    2. How you felt about it (emotional)
    3. What you learned (insights)
    4. How it relates to your goals (relevance)

    Respond in JSON format:
    {
      "memory_type": "success|failure|discovery|social|learning",
      "summary": "brief description",
      "emotional_impact": "positive|negative|neutral",
      "insights": ["insight1", "insight2", ...],
      "importance": 0.7,
      "tags": ["tag1", "tag2", ...]
    }
    """
  end

  # Helper formatting functions

  defp format_context(context) when is_map(context) do
    zone_info = case Map.get(context, "zone") do
      nil -> "No specific zone"
      zone -> "Zone: #{Map.get(zone, "name", "Unknown")} - #{Map.get(zone, "description", "")}"
    end

    social_info = case Map.get(context, "social_context") do
      nil -> "No other PACs present"
      social -> "Other PACs present: #{Map.get(social, "other_pacs_present", 0)}"
    end

    "#{zone_info}\n#{social_info}"
  end
  defp format_context(_), do: "No context information available"

  defp format_actions(actions) when is_list(actions) do
    actions
    |> Enum.map(& Map.get(&1, "action", inspect(&1)))
    |> Enum.join(", ")
  end
  defp format_actions(_), do: "No actions recorded"

  defp format_outcomes(outcomes) when is_list(outcomes) do
    outcomes
    |> Enum.map(fn outcome ->
      action = Map.get(outcome, "action", "unknown")
      success = Map.get(outcome, "success", false)
      result = if success, do: "succeeded", else: "failed"
      "#{action}: #{result}"
    end)
    |> Enum.join("\n")
  end
  defp format_outcomes(_), do: "No outcomes recorded"

  defp format_pac_profile(pac) when is_map(pac) do
    name = Map.get(pac, "name", "Unknown")
    traits = Map.get(pac, "traits", []) |> Enum.join(", ")
    mood = get_in(pac, ["state", "mood"]) || "neutral"

    "Name: #{name}\nTraits: #{traits}\nCurrent Mood: #{mood}"
  end
  defp format_pac_profile(_), do: "Profile unavailable"

  defp format_target_pacs(pacs) when is_list(pacs) do
    pacs
    |> Enum.map(&format_pac_profile/1)
    |> Enum.join("\n\n")
  end
  defp format_target_pacs(_), do: "No other PACs present"

  defp format_pac_state(state) when is_map(state) do
    stats = Map.get(state, "stats", %{})
    current_state = Map.get(state, "state", %{})
    traits = Map.get(state, "traits", [])

    """
    Stats: #{inspect(stats)}
    Current State: #{inspect(current_state)}
    Traits: #{Enum.join(traits, ", ")}
    """
  end
  defp format_pac_state(_), do: "State information unavailable"

  defp format_achievements(achievements) when is_list(achievements) and length(achievements) > 0 do
    achievements
    |> Enum.map(& "- #{inspect(&1)}")
    |> Enum.join("\n")
  end
  defp format_achievements(_), do: "No past achievements recorded"

  defp format_opportunities(opportunities) when is_list(opportunities) and length(opportunities) > 0 do
    opportunities
    |> Enum.map(& "- #{inspect(&1)}")
    |> Enum.join("\n")
  end
  defp format_opportunities(_), do: "No specific opportunities identified"

  defp format_value(value) when is_list(value), do: format_list(value)
  defp format_value(value) when is_map(value), do: format_map(value)
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value), do: inspect(value)

  defp format_map(map) when map == %{}, do: "None"
  defp format_map(map) do
    map
    |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
    |> Enum.join(", ")
  end

  defp format_list(list) when is_list(list) do
    list
    |> Enum.map(&format_value/1)
    |> Enum.join(", ")
  end
  defp format_list(_), do: "[]"
end
