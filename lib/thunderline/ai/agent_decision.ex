defmodule Thunderline.AI.AgentDecision do
  @moduledoc """
  Ash AI Resource for agent decision making using prompt-backed actions.

  Replaces the manual AgentCore.DecisionMaker with a structured, reusable prompt action.
  """

  use Ash.Resource,
    domain: Thunderline.Domain

  attributes do
    uuid_primary_key :id

    # Input attributes
    attribute :context_assessment, :map
    attribute :available_actions, {:array, :string}
    attribute :agent_goals, {:array, :string}
    attribute :constraints, :map
    attribute :time_pressure, :string

    # Output attributes
    attribute :chosen_action, :string
    attribute :reasoning, :string
    attribute :confidence, :decimal
    attribute :alternatives_considered, {:array, :string}
    attribute :risk_assessment, :map
    attribute :expected_outcome, :string

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:context_assessment, :available_actions, :agent_goals, :constraints, :time_pressure]
    end

    # Simplified action for decision making - using mock implementation for now
    action :make_decision, :struct do
      description "Make a decision based on context assessment and available options"

      argument :context_assessment, :map, allow_nil?: false
      argument :available_actions, {:array, :string}, default: []
      argument :agent_goals, {:array, :string}, default: []
      argument :constraints, :map, default: %{}
      argument :time_pressure, :string, default: "low"

      run fn input, _context ->
        # Mock implementation - replace with actual AI prompt later
        available = input.arguments.available_actions
        chosen = if Enum.empty?(available), do: "rest", else: Enum.random(available)

        {:ok,
         %{
           chosen_action: chosen,
           reasoning: "Based on current context, this action seems most appropriate",
           confidence: Decimal.new("0.7"),
           alternatives_considered: available,
           risk_assessment: %{level: "low", factors: []},
           expected_outcome: "Positive outcome expected"
         }}
      end
    end
  end

  code_interface do
    domain Thunderline.Domain

    define :make_decision,
      args: [:context_assessment, :available_actions, :agent_goals, :constraints, :time_pressure]

    define :create
  end
end
