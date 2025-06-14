defmodule Thunderline.AI.AgentMemory do
  @moduledoc """
  Ash AI Resource for agent memory formation using prompt-backed actions.

  Replaces the manual AgentCore.MemoryBuilder with structured memory creation.
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    extensions: [AshAI.Resource]

  attributes do
    uuid_primary_key :id

    # Input attributes
    attribute :action_taken, :string, allow_nil?: false
    attribute :action_result, :map, default: %{}
    attribute :context_summary, :string
    attribute :emotional_state_before, :string
    attribute :emotional_state_after, :string
    attribute :environment_details, :map, default: %{}

    # Output attributes
    attribute :memory_content, :string
    attribute :memory_tags, {:array, :string}, default: []
    attribute :importance_score, :float, default: 0.5
    attribute :emotional_impact, :string
    attribute :lessons_learned, {:array, :string}, default: []
    attribute :connections_to_existing, {:array, :string}, default: []

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:action_taken, :action_result, :context_summary,
              :emotional_state_before, :emotional_state_after, :environment_details]
    end

    prompt_action :form_memory do
      description "Create a structured memory from an agent's action and its results"

      input do
        attribute :action_taken, :string, allow_nil?: false
        attribute :action_result, :map, default: %{}
        attribute :context_summary, :string
        attribute :emotional_state_before, :string
        attribute :emotional_state_after, :string
        attribute :environment_details, :map, default: %{}
      end

      output do
        attribute :memory_content, :string
        attribute :memory_tags, {:array, :string}
        attribute :importance_score, :float
        attribute :emotional_impact, :string
        attribute :lessons_learned, {:array, :string}
        attribute :connections_to_existing, {:array, :string}
      end

      prompt """
      You are helping a PAC (Persistent Autonomous Character) agent form a meaningful memory from a recent experience.

      ## Experience Details:
      Action Taken: {{action_taken}}
      Action Result: {{action_result}}
      Context: {{context_summary}}

      ## Emotional Journey:
      Before: {{emotional_state_before}}
      After: {{emotional_state_after}}

      ## Environment:
      {{environment_details}}

      Based on this experience, create a rich, meaningful memory that will help the agent learn and grow:

      1. **Memory Content**: A narrative description of what happened, written from the agent's perspective (2-3 sentences)

      2. **Memory Tags**: 3-5 relevant tags that categorize this memory (e.g., "exploration", "success", "learning", "social", "discovery")

      3. **Importance Score**: Rate the significance of this memory for the agent's development (0.0-1.0)
        - 0.0-0.3: Routine, mundane experiences
        - 0.4-0.6: Notable experiences with some learning value
        - 0.7-0.9: Significant experiences with major impact
        - 0.9-1.0: Life-changing, transformative experiences

      4. **Emotional Impact**: How this experience affected the agent emotionally

      5. **Lessons Learned**: 1-3 key insights or lessons the agent can take from this experience

      6. **Connections to Existing**: Potential connections to past experiences or future goals

      Respond with valid JSON:
      {
        "memory_content": "...",
        "memory_tags": ["tag1", "tag2", "tag3"],
        "importance_score": 0.7,
        "emotional_impact": "...",
        "lessons_learned": ["lesson1", "lesson2"],
        "connections_to_existing": ["connection1", "connection2"]
      }
      """

      provider AshAI.Providers.OpenAI
      model "gpt-4-turbo-preview"
      temperature 0.8  # Higher creativity for memory formation
      max_tokens 700
    end
  end

  code_interface do
    domain Thunderline.Domain

    define :form_memory
    define :create
  end
end
