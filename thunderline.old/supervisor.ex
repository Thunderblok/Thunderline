defmodule Thunderline.Supervisor do
  @moduledoc """
  Main Thunderline supervisor managing core subsystems.

  Orchestrates the key components of the Thunderline substrate:
  - PAC Manager: PAC lifecycle and state management
  - Tick Orchestrator: Scheduled PAC evolution cycles
  - MCP Interface: Agent-tool communication layer
  - Memory Manager: Semantic memory and recall
  - Narrative Engine: Story context and world building
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
    @impl true
  def init(_init_arg) do
    children = [
      # PAC lifecycle management
      Thunderline.PAC.Manager,

      # Tick orchestration system
      Thunderline.Tick.Orchestrator,

      # MCP tool registry for agent capabilities
      Thunderline.MCP.ToolRegistry,

      # MCP interface for agent-tool communication
      Thunderline.MCP.Server,

      # Memory and semantic lookup
      Thunderline.Memory.Manager,

      # Narrative and world context
      Thunderline.Narrative.Engine,

      # Signal processing for inter-agent communication
      {Jido.Signal.Bus, name: Thunderline.SignalBus}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
