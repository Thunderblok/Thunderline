defmodule Thunderline.PAC.AgentTickReactor do
  @moduledoc """
  Reactor pipeline for agent tick processing using Ash AI components.

  Replaces the manual tick pipeline with a declarative DAG that chains
  context assessment → decision making → action execution → memory formation.
  """

  use Reactor

  # Input: agent struct from PAC.Agent
  input :agent

  # Step 1: Assess the agent's current context
  step :context_assessment, Thunderline.PAC.AgentTickSteps, step_name: :context_assessment do
    argument :agent, input(:agent)
  end

  # Step 2: Make a decision based on the context
  step :decision_making, Thunderline.PAC.AgentTickSteps, step_name: :decision_making do
    argument :context, result(:context_assessment)
    argument :agent, input(:agent)
  end

  # Step 3: Execute the chosen action using Ash AI tools
  step :action_execution, Thunderline.PAC.AgentTickSteps, step_name: :action_execution do
    argument :decision, result(:decision_making)
    argument :agent, input(:agent)
  end

  # Step 4: Form memories from the action and its results
  step :memory_formation, Thunderline.PAC.AgentTickSteps, step_name: :memory_formation do
    argument :context, result(:context_assessment)
    argument :decision, result(:decision_making)
    argument :action_result, result(:action_execution)
    argument :agent, input(:agent)
  end

  # Step 5: Update agent state
  step :state_update, Thunderline.PAC.AgentTickSteps, step_name: :state_update do
    argument :agent, input(:agent)
    argument :action_result, result(:action_execution)
    argument :memory_formed, result(:memory_formation)
  end
end
