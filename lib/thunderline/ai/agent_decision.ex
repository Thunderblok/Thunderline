defmodule Thunderline.AI.AgentDecision do
  @moduledoc """
  Ash AI Resource for agent decision-making using prompt-backed actions.

  Replaces the manual AgentCore.DecisionEngine with structured tool-enabled decision making.
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    extensions: [AshAI.Resource]

  attributes do
    uuid_primary_key :id

    # Input attributes
    attribute :context_summary, :string, allow_nil?: false
    attribute :emotional_state, :string, allow_nil?: false
    attribute :motivations, {:array, :string}, default: []
    attribute :priorities, {:array, :string}, default: []
    attribute :available_actions, {:array, :string}, default: []
    attribute :environmental_constraints, :map, default: %{}

    # Output attributes
    attribute :chosen_action, :string
    attribute :action_params, :map, default: %{}
    attribute :reasoning, :string
    attribute :expected_outcome, :string
    attribute :risk_assessment, :string
    attribute :confidence_score, :float, default: 0.7
    attribute :fallback_action, :string

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:context_summary, :emotional_state, :motivations, :priorities,
              :available_actions, :environmental_constraints]
    end

    # Main decision-making prompt action
    prompt_action :make_decision do
      description "Make an informed decision based on agent context and available options"

      input do
        attribute :context_summary, :string, allow_nil?: false
        attribute :emotional_state, :string, allow_nil?: false
        attribute :motivations, {:array, :string}, default: []
        attribute :priorities, {:array, :string}, default: []
        attribute :available_actions, {:array, :string}, default: []
        attribute :environmental_constraints, :map, default: %{}
      end

      output do
        attribute :chosen_action, :string
        attribute :action_params, :map
        attribute :reasoning, :string
        attribute :expected_outcome, :string
        attribute :risk_assessment, :string
        attribute :confidence_score, :float
        attribute :fallback_action, :string
      end

      prompt """
      You are making a decision for a PAC (Persistent Autonomous Character) agent.

      ## Current Context:
      Summary: {{context_summary}}
      Emotional State: {{emotional_state}}

      ## Motivations:
      {{#each motivations}}
      - {{this}}
      {{/each}}

      ## Priorities:
      {{#each priorities}}
      - {{this}}
      {{/each}}

      ## Available Actions:
      {{#each available_actions}}
      - {{this}}
      {{/each}}

      ## Environmental Constraints:
      {{environmental_constraints}}

      Based on this information, make the best decision for this agent:

      1. **Chosen Action**: Select one action from the available list that best aligns with motivations and priorities

      2. **Action Parameters**: Any specific parameters or details for executing this action

      3. **Reasoning**: Explain why this action was chosen (2-3 sentences)

      4. **Expected Outcome**: What you expect to happen as a result

      5. **Risk Assessment**: Any potential risks or downsides to consider

      6. **Confidence Score**: How confident you are in this decision (0.0-1.0)

      7. **Fallback Action**: Alternative action if the chosen one fails

      Respond with valid JSON:
      {
        "chosen_action": "action_name",
        "action_params": {...},
        "reasoning": "...",
        "expected_outcome": "...",
        "risk_assessment": "...",
        "confidence_score": 0.8,
        "fallback_action": "alternative_action"
      }
      """

      provider AshAI.Providers.OpenAI
      model "gpt-4-turbo-preview"
      temperature 0.6
      max_tokens 600
    end
  end

  code_interface do
    domain Thunderline.Domain

    define :make_decision
    define :create
  end
end
