defmodule Thunderline.AgentCore.MemoryBuilder do
  @moduledoc """
  Logs tick outcomes and stores memory results.

  API:
    store_results(pac_state, tick_outcome) :: {:ok, memory_context, metadata}
  """

  @spec store_results(map(), map()) :: {:ok, map(), map()}
  def store_results(pac_state, tick_outcome) do
    # Stub: returns unchanged memories
    memory_context = pac_state.memory_context || %{}
    metadata = %{timestamp: DateTime.utc_now()}
    {:ok, memory_context, metadata}
  end
