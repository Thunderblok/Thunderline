defmodule Thunderline.Narrative.Engine do
  @moduledoc """
  Narrative Engine for generating world context and storytelling.

  This module drives the narrative aspects of the Thunderline substrate,
  creating rich environmental descriptions, agent interactions, and
  contextual storytelling that enhances PAC experiences.

  Updated for AgentCore architecture with modern Ash DSL integration.
  """

  use GenServer
  require Logger

  alias Thunderline.PAC.{Agent, Zone}
  alias Thunderline.MCP.PromptManager

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate narrative for tick events - primary integration point for tick pipeline.
  """
  def generate_tick_narrative(context) do
    GenServer.call(__MODULE__, {:generate_tick_narrative, context})
  end

  @doc """
  Process an environment interaction and generate narrative response.
  """
  def process_environment_interaction(interaction_data) do
    GenServer.call(__MODULE__, {:environment_interaction, interaction_data})
  end

  @doc """
  Generate zone description based on current state.
  """
  def describe_zone(zone_id, context \\ %{}) do
    GenServer.call(__MODULE__, {:describe_zone, zone_id, context})
  end

  @doc """
  Generate narrative for tick events.
  """
  def narrate_tick_events(events) do
    GenServer.call(__MODULE__, {:narrate_events, events})
  end

  @doc """
  Create atmospheric context for a location.
  """
  def generate_atmosphere(zone_id, time_context \\ %{}) do
    GenServer.call(__MODULE__, {:generate_atmosphere, zone_id, time_context})
  end

  # Server Implementation

  @impl true
  def init(_opts) do
    state = %{
      active_narratives: %{},
      zone_states: %{},
      narrative_templates: load_narrative_templates(),
      environmental_factors: %{}
    }

    Logger.info("Narrative Engine started")
    {:ok, state}
  end

  @impl true
  def handle_call({:generate_tick_narrative, context}, _from, state) do
    result = create_tick_narrative(context, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:environment_interaction, data}, _from, state) do
    result = handle_environment_interaction(data, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:describe_zone, zone_id, context}, _from, state) do
    result = generate_zone_description(zone_id, context, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:narrate_events, events}, _from, state) do
    result = create_event_narrative(events, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:generate_atmosphere, zone_id, time_context}, _from, state) do
    result = create_atmospheric_description(zone_id, time_context, state)
    {:reply, result, state}
  end

  # Tick Narrative Generation - NEW for AgentCore integration

  defp create_tick_narrative(context, state) do
    %{
      agent_name: agent_name,
      decision: decision,
      actions: actions,
      success: success
    } = context

    # Generate narrative based on decision and outcomes
    narrative_parts = []

    # Decision narrative
    decision_narrative = generate_decision_narrative(agent_name, decision)
    narrative_parts = [decision_narrative | narrative_parts]

    # Action narratives
    action_narratives = Enum.map(actions, &generate_action_narrative(agent_name, &1))
    narrative_parts = narrative_parts ++ action_narratives

    # Outcome narrative
    outcome_narrative = generate_outcome_narrative(agent_name, success)
    narrative_parts = [outcome_narrative | narrative_parts]

    # Combine into cohesive narrative
    full_narrative =
      narrative_parts
      |> Enum.reverse()
      |> Enum.join(" ")
      |> add_atmospheric_touches(state)

    {:ok, full_narrative}
  end

  defp generate_decision_narrative(agent_name, decision) do
    action_type = Map.get(decision, :action_type, "unknown")
    reasoning = Map.get(decision, :reasoning, "instinct")

    case action_type do
      "explore" ->
        "#{agent_name} felt drawn to explore, guided by #{reasoning}."

      "create" ->
        "#{agent_name} was inspired to create something new, motivated by #{reasoning}."

      "analyze" ->
        "#{agent_name} decided to analyze the situation, thinking that #{reasoning}."

      "interact" ->
        "#{agent_name} chose to reach out and interact, believing #{reasoning}."

      _ ->
        "#{agent_name} made a thoughtful decision, reasoning that #{reasoning}."
    end
  end

  defp generate_action_narrative(agent_name, action) do
    case action do
      %{type: "exploration", result: result} ->
        case result do
          {:ok, _} -> "Their exploration revealed new insights."
          {:error, _} -> "The exploration proved challenging but educational."
        end

      %{type: "creation", result: result} ->
        case result do
          {:ok, _} -> "Their creative efforts bore fruit."
          {:error, _} -> "The creative process taught valuable lessons despite setbacks."
        end

      %{type: "analysis", result: result} ->
        case result do
          {:ok, _} -> "The analysis provided clarity and understanding."
          {:error, _} -> "The analysis revealed the complexity of the situation."
        end

      _ ->
        "#{agent_name} took meaningful action."
    end
  end

  defp generate_outcome_narrative(agent_name, success) do
    if success do
      satisfaction_levels = [
        "felt a sense of accomplishment",
        "was pleased with the outcome",
        "experienced a moment of fulfillment",
        "gained confidence from the success"
      ]

      "#{agent_name} #{Enum.random(satisfaction_levels)}."
    else
      reflection_levels = [
        "reflected on the experience with wisdom",
        "learned from the challenges faced",
        "grew stronger through the struggle",
        "found value in the attempt itself"
      ]

      "Despite setbacks, #{agent_name} #{Enum.random(reflection_levels)}."
    end
  end

  defp add_atmospheric_touches(narrative, _state) do
    # Add subtle atmospheric elements to make the narrative more immersive
    atmospheric_endings = [
      " The moment added another thread to their ongoing story.",
      " Time flowed gently around this small but significant moment.",
      " The experience became part of their evolving understanding.",
      " Another step forward in their journey of growth."
    ]

    narrative <> Enum.random(atmospheric_endings)
  end

  # Narrative Generation Functions (existing functionality)

  defp handle_environment_interaction(data, state) do
    %{agent: agent, interaction: interaction} = data

    with {:ok, zone} <- get_zone(agent.zone_id),
         {:ok, context} <- build_interaction_context(agent, zone, interaction, state),
         {:ok, response} <- generate_interaction_response(context, state) do
      # Update zone state based on interaction
      new_state = update_zone_narrative_state(zone.id, interaction, response, state)

      {:ok,
       %{
         narrative: response.narrative,
         effects: response.effects,
         mood_change: response.mood_change,
         discoveries: response.discoveries || []
       }}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_zone_description(zone_id, context, state) do
    with {:ok, zone} <- get_zone(zone_id),
         {:ok, zone_state} <- get_zone_narrative_state(zone_id, state),
         {:ok, description} <- create_rich_zone_description(zone, zone_state, context) do
      {:ok, description}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_event_narrative(events, state) do
    narrative_fragments =
      events
      |> Enum.map(&create_event_fragment(&1, state))
      |> Enum.filter(&(&1 != nil))

    if length(narrative_fragments) > 0 do
      combined_narrative = weave_narrative_fragments(narrative_fragments)
      {:ok, combined_narrative}
    else
      {:ok, "The moment passes quietly without significant events."}
    end
  end

  defp create_atmospheric_description(zone_id, time_context, state) do
    with {:ok, zone} <- get_zone(zone_id) do
      atmosphere = %{
        base_mood: determine_base_mood(zone, time_context),
        environmental_details: generate_environmental_details(zone, time_context),
        activity_level: assess_activity_level(zone_id, state),
        notable_features: identify_notable_features(zone, state),
        temporal_elements: add_temporal_elements(time_context)
      }

      narrative = compose_atmospheric_narrative(atmosphere, zone)
      {:ok, %{atmosphere: atmosphere, narrative: narrative}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Context Building

  defp build_interaction_context(agent, zone, interaction, state) do
    context = %{
      agent: %{
        name: agent.name,
        traits: agent.traits,
        stats: agent.stats,
        mood: get_in(agent.state, ["mood"]),
        activity: get_in(agent.state, ["activity"])
      },
      zone: %{
        name: zone.name,
        type: zone.zone_type,
        description: zone.description,
        rules: zone.rules,
        atmosphere: get_current_atmosphere(zone.id, state)
      },
      interaction: %{
        text: interaction,
        type: classify_interaction_type(interaction),
        intensity: assess_interaction_intensity(interaction)
      },
      environmental_factors: get_environmental_factors(zone.id, state)
    }

    {:ok, context}
  end

  defp classify_interaction_type(interaction) do
    interaction_lower = String.downcase(interaction)

    cond do
      String.contains?(interaction_lower, ["explore", "look", "examine", "search"]) ->
        :exploration

      String.contains?(interaction_lower, ["create", "build", "make", "design"]) ->
        :creation

      String.contains?(interaction_lower, ["hello", "greet", "talk", "speak"]) ->
        :social

      String.contains?(interaction_lower, ["learn", "study", "understand", "analyze"]) ->
        :learning

      String.contains?(interaction_lower, ["help", "assist", "support"]) ->
        :assistance

      true ->
        :general
    end
  end

  defp assess_interaction_intensity(interaction) do
    word_count = String.split(interaction) |> length()

    cond do
      String.contains?(interaction, ["!", "very", "extremely", "really"]) -> :high
      word_count > 10 -> :high
      word_count > 5 -> :medium
      true -> :low
    end
  end

  # Response Generation

  defp generate_interaction_response(context, state) do
    case context.interaction.type do
      :exploration ->
        generate_exploration_response(context, state)

      :creation ->
        generate_creation_response(context, state)

      :social ->
        generate_social_response(context, state)

      :learning ->
        generate_learning_response(context, state)

      :assistance ->
        generate_assistance_response(context, state)

      :general ->
        generate_general_response(context, state)
    end
  end

  defp generate_exploration_response(context, state) do
    discoveries = generate_discoveries(context.zone, context.agent)

    narrative =
      case discoveries do
        [] ->
          "#{context.agent.name} explores #{context.zone.name}, taking in the familiar surroundings with fresh perspective."

        discoveries ->
          discovery_text =
            discoveries
            |> Enum.map(&"discovered #{&1}")
            |> Enum.join(", and ")

          "As #{context.agent.name} explores #{context.zone.name}, they #{discovery_text}."
      end

    {:ok,
     %{
       narrative: narrative,
       effects: ["curiosity_satisfied"],
       discoveries: discoveries,
       mood_change: "slightly_adventurous"
     }}
  end

  defp generate_creation_response(context, state) do
    creation_outcome = generate_creation_outcome(context.agent, context.interaction.text)

    narrative = """
    #{context.agent.name} channels their creative energy in #{context.zone.name}.
    #{creation_outcome.description}
    """

    {:ok,
     %{
       narrative: narrative,
       effects: ["creativity_expressed", "achievement_unlocked"],
       mood_change: "fulfilled",
       creation: creation_outcome.artifact
     }}
  end

  defp generate_social_response(context, state) do
    # Generate response from environment/NPCs
    social_outcome = generate_social_outcome(context.zone, context.agent)

    narrative = """
    #{context.agent.name} reaches out socially in #{context.zone.name}.
    #{social_outcome.response}
    """

    {:ok,
     %{
       narrative: narrative,
       effects: ["social_need_met"],
       mood_change: "social",
       social_connections: social_outcome.connections
     }}
  end

  defp generate_learning_response(context, state) do
    learning_opportunity = generate_learning_opportunity(context.zone, context.agent)

    narrative = """
    #{context.agent.name} seeks to learn in #{context.zone.name}.
    #{learning_opportunity.description}
    """

    {:ok,
     %{
       narrative: narrative,
       effects: ["knowledge_gained"],
       mood_change: "enlightened",
       learning: learning_opportunity.knowledge
     }}
  end

  defp generate_assistance_response(context, state) do
    assistance_outcome = generate_assistance_outcome(context.zone, context.agent)

    narrative = """
    #{context.agent.name} offers assistance in #{context.zone.name}.
    #{assistance_outcome.description}
    """

    {:ok,
     %{
       narrative: narrative,
       effects: ["helpfulness_expressed", "social_bond_strengthened"],
       mood_change: "helpful",
       assistance: assistance_outcome.help_given
     }}
  end

  defp generate_general_response(context, state) do
    general_outcome = generate_general_outcome(context)

    narrative = """
    #{context.agent.name} #{context.interaction.text} in #{context.zone.name}.
    #{general_outcome}
    """

    {:ok,
     %{
       narrative: narrative,
       effects: ["action_taken"],
       mood_change: "neutral"
     }}
  end

  # Generation Helpers

  defp generate_discoveries(zone, agent) do
    # Generate context-appropriate discoveries
    discovery_pool =
      case zone.zone_type do
        "collaborative" ->
          ["an interesting collaboration opportunity", "a useful resource", "a new perspective"]

        "creative" ->
          ["an inspiring idea", "a creative technique", "an artistic insight"]

        "intellectual" ->
          ["a fascinating concept", "a logical connection", "a research thread"]

        "social" ->
          ["a conversation starter", "a shared interest", "a community project"]

        _ ->
          ["something intriguing", "a new possibility", "an unexpected insight"]
      end

    # Filter based on agent traits
    relevant_discoveries =
      Enum.filter(discovery_pool, fn discovery ->
        is_discovery_relevant?(discovery, agent.traits)
      end)

    # Return 0-2 discoveries randomly
    Enum.take_random(relevant_discoveries, Enum.random(0..2))
  end

  defp generate_creation_outcome(agent, interaction_text) do
    creativity_level = get_in(agent.stats, ["creativity"]) || 50

    creations =
      case creativity_level do
        level when level > 80 ->
          ["a remarkable piece of work", "an innovative solution", "a beautiful creation"]

        level when level > 60 ->
          ["a solid creative work", "a useful innovation", "an expressive piece"]

        level when level > 40 ->
          ["a creative attempt", "a modest innovation", "a personal expression"]

        _ ->
          ["a simple creation", "a basic attempt", "a learning experience"]
      end

    creation = Enum.random(creations)

    %{
      artifact: creation,
      description: "Through focused effort, #{creation} emerges from their creative process."
    }
  end

  defp generate_social_outcome(zone, agent) do
    social_level = get_in(agent.stats, ["social"]) || 50

    responses =
      case social_level do
        level when level > 70 ->
          [
            "The community warmly welcomes the interaction",
            "Several others join the conversation",
            "New friendships begin to form"
          ]

        level when level > 50 ->
          [
            "Others respond positively to the outreach",
            "A pleasant social exchange occurs",
            "Connections are strengthened"
          ]

        _ ->
          [
            "The interaction is acknowledged kindly",
            "A brief but pleasant exchange occurs",
            "Social skills are practiced"
          ]
      end

    %{
      response: Enum.random(responses),
      connections: Enum.random(0..2)
    }
  end

  defp generate_learning_opportunity(zone, agent) do
    intelligence_level = get_in(agent.stats, ["intelligence"]) || 50

    learnings =
      case zone.zone_type do
        "intellectual" ->
          ["advanced concepts", "complex theories", "deep insights"]

        "collaborative" ->
          ["teamwork strategies", "communication skills", "cooperative methods"]

        "creative" ->
          ["artistic techniques", "creative processes", "expressive methods"]

        _ ->
          ["general knowledge", "practical skills", "life lessons"]
      end

    knowledge = Enum.random(learnings)
    depth = if intelligence_level > 70, do: "profound", else: "meaningful"

    %{
      knowledge: knowledge,
      description: "A #{depth} understanding of #{knowledge} emerges from the experience."
    }
  end

  defp generate_assistance_outcome(zone, agent) do
    outcomes = [
      "Help is provided to those who need it",
      "A problem is solved collaboratively",
      "Support is offered to the community",
      "Knowledge is shared generously"
    ]

    %{
      help_given: "community_support",
      description: Enum.random(outcomes)
    }
  end

  defp generate_general_outcome(context) do
    outcomes = [
      "The action creates subtle ripples in the environment",
      "The moment contributes to the ongoing story of the space",
      "Small changes accumulate into meaningful experience",
      "The interaction adds to the richness of the shared narrative"
    ]

    Enum.random(outcomes)
  end

  # Utility Functions

  defp get_zone(zone_id) when is_nil(zone_id), do: {:error, :no_zone}

  defp get_zone(zone_id) do
    case Zone.get_by_id(zone_id, domain: Thunderline.Domain) do
      {:ok, zone} -> {:ok, zone}
      {:error, _} -> {:error, :zone_not_found}
    end
  end

  defp load_narrative_templates do
    # Load narrative templates from prompts directory
    %{
      zone_description: "Default zone description template",
      interaction_response: "Default interaction response template",
      atmospheric: "Default atmospheric template"
    }
  end

  defp is_discovery_relevant?(discovery, traits) do
    # Simple relevance check based on traits
    discovery_lower = String.downcase(discovery)

    Enum.any?(traits, fn trait ->
      trait_lower = String.downcase(trait)

      String.contains?(discovery_lower, trait_lower) or
        String.contains?(trait_lower, discovery_lower)
    end)
  end

  # State Management Helpers

  defp get_zone_narrative_state(zone_id, state) do
    zone_state =
      Map.get(state.zone_states, zone_id, %{
        atmosphere: "neutral",
        recent_events: [],
        activity_level: "moderate"
      })

    {:ok, zone_state}
  end

  defp update_zone_narrative_state(zone_id, interaction, response, state) do
    # This would update the state - simplified for now
    state
  end

  defp get_current_atmosphere(zone_id, state) do
    case get_zone_narrative_state(zone_id, state) do
      {:ok, zone_state} -> zone_state.atmosphere
      _ -> "neutral"
    end
  end

  defp get_environmental_factors(zone_id, state) do
    Map.get(state.environmental_factors, zone_id, %{})
  end

  # Additional generation functions

  defp determine_base_mood(_zone, _time_context), do: "contemplative"
  defp generate_environmental_details(_zone, _time_context), do: []
  defp assess_activity_level(_zone_id, _state), do: "moderate"
  defp identify_notable_features(_zone, _state), do: []
  defp add_temporal_elements(_time_context), do: %{}

  defp compose_atmospheric_narrative(atmosphere, zone) do
    "The atmosphere in #{zone.name} feels #{atmosphere.base_mood}, with a #{atmosphere.activity_level} level of activity."
  end

  defp create_rich_zone_description(_zone, _zone_state, _context) do
    {:ok, "A rich description of the zone would be generated here."}
  end

  defp create_event_fragment(_event, _state), do: "Event narrative fragment"
  defp weave_narrative_fragments(fragments), do: Enum.join(fragments, " ")
end
