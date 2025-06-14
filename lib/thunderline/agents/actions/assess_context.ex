defmodule Thunderline.Agents.Actions.AssessContext do
  @moduledoc """
  Action for assessing PAC Agent context and situation.
  This module now delegates the core assessment logic to Thunderline.AgentCore.ContextAssessor.
  """

  alias Thunderline.AgentCore.ContextAssessor

  # The run/2 function now matches the expected parameters from the original schema.
  # It extracts these parameters and calls the core assessor module.
  @spec run(params :: map(), context :: map()) :: {:ok, {map(), map()}} | {:error, any()}
  def run(params, _context) do
    # Defaulting missing optional params as per original schema
    agent = params[:agent]
    zone_context = params[:zone_context] || %{}
    memories = params[:memories] || []
    available_tools = params[:available_tools] || []
    tick_count = params[:tick_count] || 0
    federation_context = params[:federation_context] || %{}

    # Ensure required agent param is present
    if is_nil(agent) do
      {:error, "Missing required parameter: :agent"}
    else
      ContextAssessor.run(
        agent,
        zone_context,
        memories,
        available_tools,
        tick_count,
        federation_context
      )
    end
  end
end
