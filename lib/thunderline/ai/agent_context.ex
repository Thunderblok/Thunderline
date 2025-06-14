defmodule Thunderline.AI.AgentContext do
  @moduledoc """
  Ash AI Resource for agent context assessment using prompt-backed actions.

  Replaces the manual AgentCore.ContextAssessor with a structured, reusable prompt action.
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    extensions: [AshAI.Resource]

  attributes do
    uuid_primary_key :id

    # Input attributes
    attribute :agent_traits, :map, allow_nil?: false
    attribute :zone_data, :map, default: %{}
    attribute :top_memories, {:array, :string}, default: []
    attribute :current_stats, :map, default: %{}
    attribute :recent_interactions, {:array, :string}, default: []

    # Output attributes
    attribute :summary, :string
    attribute :emotional_state, :string
    attribute :motivations, {:array, :string}, default: []
    attribute :priorities, {:array, :string}, default: []
    attribute :environmental_factors, :map, default: %{}
    attribute :confidence_level, :float, default: 0.7

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:agent_traits, :zone_data, :top_memories, :current_stats, :recent_interactions]
    end

    # The main Ash AI prompt action for context assessment
    prompt_action :assess_context do
      description "Analyze agent's current context and determine emotional state and motivations"

      input do
        attribute :agent_traits, :map, allow_nil?: false
        attribute :zone_data, :map, default: %{}
        attribute :top_memories, {:array, :string}, default: []
        attribute :current_stats, :map, default: %{}
        attribute :recent_interactions, {:array, :string}, default: []
      end

      output do
        attribute :summary, :string
        attribute :emotional_state, :string
        attribute :motivations, {:array, :string}
        attribute :priorities, {:array, :string}
        attribute :environmental_factors, :map
        attribute :confidence_level, :float
      end

      prompt """
      You are analyzing the psychological and environmental context of a PAC (Persistent Autonomous Character) agent.

      ## Agent Profile:
      Traits: {{agent_traits}}
      Current Stats: {{current_stats}}

      ## Environment:
      Zone Data: {{zone_data}}

      ## Memory Context:
      Recent Memories: {{#each top_memories}}
      - {{this}}
      {{/each}}

      ## Recent Interactions:
      {{#each recent_interactions}}
      - {{this}}
      {{/each}}

      Based on this information, provide a comprehensive psychological and environmental assessment:

      1. **Summary**: A concise overview of the agent's current situation (2-3 sentences)

      2. **Emotional State**: Current emotional condition (e.g., "curious and energetic", "tired but determined", "anxious about unknown territory")

      3. **Motivations**: List 2-4 key motivations driving the agent right now

      4. **Priorities**: List 2-4 immediate priorities for action

      5. **Environmental Factors**: Key environmental elements affecting decision-making

      6. **Confidence Level**: Rate your confidence in this assessment (0.0-1.0)

      Respond with valid JSON matching this structure:
      {
        "summary": "...",
        "emotional_state": "...",
        "motivations": ["...", "..."],
        "priorities": ["...", "..."],
        "environmental_factors": {...},
        "confidence_level": 0.8
      }
      """

      # Configure the AI provider
      provider AshAI.Providers.OpenAI
      model "gpt-4-turbo-preview"
      temperature 0.7
      max_tokens 800
    end
  end

  code_interface do
    domain Thunderline.Domain

    define :assess_context
    define :create
  end
end
