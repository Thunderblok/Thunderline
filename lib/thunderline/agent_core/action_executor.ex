defmodule Thunderline.AgentCore.ActionExecutor do
  @moduledoc """
  Executes a decision and returns updated PAC state and outcome.

  API:
    run(decision, pac_state) :: {updated_pac_state, outcome, metadata}
  """

  @spec run(map(), map()) :: {map(), map(), map()}
  def run(%{action: action, mods: _mods}, pac_state) do
    # Simple executor: no state change, just log
    updated = pac_state
    outcome = %{performed: action}
    metadata = %{timestamp: DateTime.utc_now()}
    {updated, outcome, metadata}
  end
