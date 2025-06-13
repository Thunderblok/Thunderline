defmodule Thunderline.AgentCore.DecisionEngine do
  @moduledoc """
  Chooses the next action based on PAC state and context.

  API:
    make_decision(pac_state, context_map) :: {decision_struct, metadata}
  """

  defmodule Decision do
    @moduledoc "A decision struct with action, reason, and modifiers."
    defstruct [:action, :reason, :mods]
  end

  @spec make_decision(map(), map()) :: {Decision.t(), map()}
  def make_decision(pac_state, context) do
    # Example simple logic: choose :idle
    decision = %Decision{action: :idle, reason: "default_idle", mods: %{}}
    metadata = %{timestamp: DateTime.utc_now()}
    {decision, metadata}
  end
end
