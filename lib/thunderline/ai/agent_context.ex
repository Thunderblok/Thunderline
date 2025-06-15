defmodule Thunderline.AI.AgentContext do
  @moduledoc """
  Ash AI Resource for agent context assessment using prompt-backed actions.

  Replaces the manual AgentCore.ContextAssessor with a structured, reusable prompt action.
  """

  use Ash.Resource,
    domain: Thunderline.Domain

  attributes do
    uuid_primary_key :id

    # Input attributes
    attribute :agent_traits, :map
    attribute :zone_data, :map
    attribute :top_memories, {:array, :string}
    attribute :current_stats, :map
    attribute :recent_interactions, {:array, :string}

    # Output attributes
    attribute :summary, :string
    attribute :emotional_state, :string
    attribute :motivations, {:array, :string}
    attribute :priorities, {:array, :string}
    attribute :environmental_factors, :map
    attribute :confidence_level, :decimal

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:agent_traits, :zone_data, :top_memories, :current_stats, :recent_interactions]
    end    # Simplified action for context assessment - using mock implementation for now
    action :assess_context, :struct do
      description "Analyze agent's current context and determine emotional state and motivations"

      argument :agent_traits, :map, allow_nil?: false
      argument :zone_data, :map, default: %{}
      argument :top_memories, {:array, :string}, default: []
      argument :current_stats, :map, default: %{}
      argument :recent_interactions, {:array, :string}, default: []

      run fn input, _context ->
        # Mock implementation - replace with actual AI prompt later
        {:ok, %{
          summary: "Agent is in a stable state with moderate energy levels",
          emotional_state: "curious and alert",
          motivations: ["explore surroundings", "maintain social connections"],
          priorities: ["assess immediate environment", "plan next action"],
          environmental_factors: %{weather: "clear", activity_level: "moderate"},
          confidence_level: Decimal.new("0.8")
        }}
      end
    end
  end

  code_interface do
    domain Thunderline.Domain

    define :assess_context, args: [:agent_traits, :zone_data, :top_memories, :current_stats, :recent_interactions]
    define :create
  end
end
