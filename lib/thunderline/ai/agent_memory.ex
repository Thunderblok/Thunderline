defmodule Thunderline.AI.AgentMemory do
  @moduledoc """
  Ash AI Resource for agent memory formation using prompt-backed actions.

  Replaces the manual memory formation logic with a structured, reusable prompt action.
  """

  use Ash.Resource,
    domain: Thunderline.Domain

  attributes do
    uuid_primary_key :id

    # Input attributes
    attribute :context, :map
    attribute :decision, :map
    attribute :action_result, :map
    attribute :agent_id, :string
    attribute :tick_id, :string

    # Output attributes
    attribute :memory_content, :string
    attribute :memory_type, :string
    attribute :importance_score, :decimal
    attribute :emotional_weight, :decimal
    attribute :tags, {:array, :string}
    attribute :connections, {:array, :string}

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:context, :decision, :action_result, :agent_id, :tick_id]
    end

    # Simplified action for memory formation - using mock implementation for now
    action :form_memory, :struct do
      description "Form a memory from the agent's experience"

      argument :context, :map, allow_nil?: false
      argument :decision, :map, allow_nil?: false
      argument :action_result, :map, allow_nil?: false
      argument :agent_id, :string, allow_nil?: false
      argument :tick_id, :string, allow_nil?: false

      run fn input, _context ->
        # Mock implementation - replace with actual AI prompt later
        {:ok,
         %{
           memory_content:
             "Completed action #{input.arguments.decision["chosen_action"]} successfully",
           memory_type: "experience",
           importance_score: Decimal.new("0.6"),
           emotional_weight: Decimal.new("0.5"),
           tags: ["action", "experience"],
           connections: []
         }}
      end
    end
  end

  code_interface do
    domain Thunderline.Domain

    define :form_memory, args: [:context, :decision, :action_result, :agent_id, :tick_id]
    define :create
  end
end
