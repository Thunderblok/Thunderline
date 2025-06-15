defmodule Thunderline.Agents.Actions.MakeDecision do
  @moduledoc """
  Action for PAC Agent decision making based on assessed context.
  This module now delegates the core decision logic to Thunderline.AgentCore.DecisionEngine.
  """

  alias Thunderline.AgentCore.DecisionEngine

  # The run/2 function now matches the expected parameters from the original schema.
  # It extracts these parameters and calls the core decision engine module.
  @spec run(params :: map(), context :: map()) :: {:ok, {map(), map()}} | {:error, any()}
  def run(params, _ctx) do
    assessment = params[:assessment]
    agent_config = params[:agent_config]
    # Default from original schema
    reasoning_mode = params[:reasoning_mode] || :balanced

    # Ensure required parameters are present
    cond do
      is_nil(assessment) ->
        {:error, "Missing required parameter: :assessment"}

      is_nil(agent_config) ->
        {:error, "Missing required parameter: :agent_config"}

      true ->
        DecisionEngine.make_decision(
          assessment,
          agent_config,
          reasoning_mode
        )
    end
  end
end
