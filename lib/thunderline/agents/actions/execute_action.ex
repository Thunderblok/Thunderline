defmodule Thunderline.Agents.Actions.ExecuteAction do
  @moduledoc """
  Action for executing PAC decisions.
  This module now delegates the core action execution logic to Thunderline.AgentCore.ActionExecutor.
  """

  alias Thunderline.AgentCore.ActionExecutor

  # The run/2 function now matches the expected parameters from the original schema.
  # It extracts these parameters and calls the core action executor module.
  @spec run(params :: map(), context :: map()) :: {:ok, {map(), map(), map()}} | {:error, any()}
  def run(params, _jido_context) do
    # Extract parameters based on original schema
    decision = params[:decision]
    pac_config = params[:pac_config]
    # This contains zone_context etc.
    context = params[:context]
    # Default from original schema
    available_tools = params[:available_tools] || []

    # Ensure required parameters are present
    cond do
      is_nil(decision) ->
        {:error, "Missing required parameter: :decision"}

      is_nil(pac_config) ->
        {:error, "Missing required parameter: :pac_config"}

      is_nil(context) ->
        # Context is essential for check_prerequisites, even if it's an empty map.
        # Depending on strictness, could default to %{} or error out.
        # For now, let's require it as per schema.
        {:error, "Missing required parameter: :context"}

      true ->
        ActionExecutor.run(
          decision,
          pac_config,
          context,
          available_tools
        )
    end
  end
end
