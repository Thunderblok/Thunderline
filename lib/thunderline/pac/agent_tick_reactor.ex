defmodule Thunderline.PAC.AgentTickReactor do
  @moduledoc """
  Reactor pipeline for agent tick processing using Ash AI components.

  Replaces the manual tick pipeline with a declarative DAG that chains
  context assessment → decision making → action execution → memory formation.
  """

  use Reactor

  # Input: agent struct from PAC.Agent
  input(:agent)
  # Step 1: Assess the agent's current context
  step :context_assessment do
    impl Thunderline.PAC.AgentTickSteps
    argument :agent, input(:agent)
    argument :step_name, value(:context_assessment)
  end

  # Step 2: Make a decision based on the context
  step :decision_making do
    impl Thunderline.PAC.AgentTickSteps
    argument :context, result(:context_assessment)
    argument :agent, input(:agent)
    argument :step_name, value(:decision_making)
  end

  # Step 3: Execute the chosen action using Ash AI tools
  step :action_execution do
    impl Thunderline.PAC.AgentTickSteps
    argument :decision, result(:decision_making)
    argument :agent, input(:agent)
    argument :step_name, value(:action_execution)
  end

  # Step 4: Form memories from the action and its results
  step :memory_formation do
    impl Thunderline.PAC.AgentTickSteps
    argument :context, result(:context_assessment)
    argument :decision, result(:decision_making)
    argument :action_result, result(:action_execution)
    argument :agent, input(:agent)
    argument :step_name, value(:memory_formation)
  end

  # Step 5: Update agent state
  step :state_update do
    impl Thunderline.PAC.AgentTickSteps
    argument :agent, input(:agent)
    argument :action_result, result(:action_execution)
    argument :memory_formed, result(:memory_formation)
    argument :step_name, value(:state_update)
  end
end
