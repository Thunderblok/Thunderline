defmodule Thunderline.AgentCore.ContextAssessor do
  @moduledoc """
  Extracts and summarizes PAC state, zone context, memories, and modifiers.

  API:
    run(pac_state, zone_context, memory_context, modifiers) :: {context_map, metadata}
  """

  @type pac_state :: map()
  @type zone_context :: map()
  @type memory_context :: map()
  @type modifiers :: map()
  @type context_map :: map()
  @type metadata :: map()

  @spec run(pac_state(), zone_context(), memory_context(), modifiers()) :: {context_map(), metadata()}
  def run(pac_state, zone_context, memory_context, modifiers) do
    context = %{
      stats: pac_state.stats,
      traits: pac_state.traits,
      zone: zone_context,
      memories: memory_context,
      mods: modifiers
    }
    metadata = %{timestamp: DateTime.utc_now()}
    {context, metadata}
  end
