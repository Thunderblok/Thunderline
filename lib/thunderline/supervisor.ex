defmodule Thunderline.Supervisor do
  @moduledoc """
  Supervisor for core Thunderline subsystems.

  This supervisor manages the core agent and simulation infrastructure,
  separate from the Phoenix web application concerns.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Memory subsystem
      Thunderline.Memory.Manager,

      # MCP server
      Thunderline.MCP.Server,

      # Tool registry
      Thunderline.MCP.ToolRegistry,

      # PAC Manager
      Thunderline.PAC.Manager,

      # Tick orchestrator
      Thunderline.Tick.Orchestrator,

      # Broadway pipelines for concurrent event processing
      {Thunderline.Tick.Broadway, []},
      {Thunderline.Zone.EventBroadway, []},

      # Zone orchestrator (global zone tick updates)
      Thunderline.World.ZoneOrchestrator,

      # Narrative engine
      Thunderline.Narrative.Engine,

      # Presence tracking
      ThunderlineWeb.Presence
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
