defmodule Thunderline.Agents.Actions.FormMemory do
  @moduledoc """
  Action for forming new memories from PAC experiences.
  This module now delegates the core memory formation logic to Thunderline.AgentCore.MemoryBuilder.
  """

  alias Thunderline.AgentCore.MemoryBuilder

  # The run/2 function now matches the expected parameters from the original schema.
  # It extracts these parameters and calls the core memory builder module.
  @spec run(params :: map(), jido_context :: map()) :: {:ok, map()} | {:error, any()}
  def run(params, _jido_context) do
    # Extract parameters based on original schema
    experience = params[:experience]
    pac_config = params[:pac_config]
    # 'context' in the schema refers to the tick_context for memory formation
    tick_context = params[:context]
    # Default from original schema
    previous_state = params[:previous_state] || %{}

    # Ensure required parameters are present
    cond do
      is_nil(experience) ->
        {:error, "Missing required parameter: :experience"}

      is_nil(pac_config) ->
        {:error, "Missing required parameter: :pac_config"}

      is_nil(tick_context) ->
        # tick_context is crucial for contextualizing memories
        {:error, "Missing required parameter: :context (for tick_context)"}

      true ->
        MemoryBuilder.store_results(
          experience,
          pac_config,
          tick_context,
          previous_state
        )
    end
  end
end
