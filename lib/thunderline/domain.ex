defmodule Thunderline.Domain do
  @moduledoc """
  Thunderline Ash Domain - Central coordination for all resources.
  """
  use Ash.Domain
  resources do
    # Core PAC resources
    resource Thunderline.PAC.Agent
    resource Thunderline.PAC.Zone
    resource Thunderline.PAC.Mod

    # Memory system
    resource Thunderline.Memory.MemoryNode
    resource Thunderline.Memory.MemoryEdge

    # Tick system
    resource Thunderline.Tick.Log

    # Spatial system
    resource Thunderline.OKO.GridWorld
    resource Thunderline.GridWorld.MapCoordinate

    # AI Agent system (Ash AI powered)
    resource Thunderline.AI.AgentContext
    resource Thunderline.AI.AgentDecision
    resource Thunderline.AI.AgentMemory

    # AI Tools
    resource Thunderline.AI.Tools.Rest
    resource Thunderline.AI.Tools.Explore
    resource Thunderline.AI.Tools.Socialize
  end

  authorization do
    authorize :by_default
  end
end
