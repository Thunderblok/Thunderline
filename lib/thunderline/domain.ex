defmodule Thunderline.Domain do
  @moduledoc """
  Thunderline Ash Domain - Central coordination for all resources.
  """

  use Ash.Domain

  resources do
    resource Thunderline.Accounts.User
    resource Thunderline.Accounts.Token
    resource Thunderline.PAC.Agent
    resource Thunderline.PAC.Zone
    resource Thunderline.PAC.Mod
    resource Thunderline.Memory.MemoryNode
    resource Thunderline.Memory.MemoryEdge
    resource Thunderline.Tick.TickLog
    resource Thunderline.Narrative.NarrativeEvent
  end

  authorization do
    authorize :by_default
  end
end
