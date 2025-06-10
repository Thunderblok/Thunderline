defmodule Thunderline.Domain do
  @moduledoc """
  Thunderline Ash Domain - Central coordination point for all Thunderline resources.

  This domain manages the core entities of the Thunderline substrate:
  - PACs (Personal Autonomous Creations)
  - Zones (Environmental containers)
  - Mods (PAC trait modifications)
  - Memories (Semantic memory storage)
  - Ticks (Evolution cycle logs)

  The domain provides declarative resource management with automatic
  API generation, validation, and database interaction.
  """

  use Ash.Domain

  # ========================================
  # Resource Registration
  # ========================================

  resources do
    # Core PAC entities
    resource Thunderline.PAC.PAC
    resource Thunderline.PAC.Zone
    resource Thunderline.PAC.Mod

    # Memory and evolution
    resource Thunderline.Memory.Memory
    resource Thunderline.Memory.Embedding
    resource Thunderline.Tick.Log

    # MCP and tooling
    resource Thunderline.MCP.Tool
    resource Thunderline.MCP.Session

    # Agent management
    resource Thunderline.Agent.Agent
    resource Thunderline.Agent.State
  end

  # ========================================
  # Domain Authorization
  # ========================================

  authorization do
    # Require authorization for all operations
    require_actor? true

    # Default authorization policy
    authorize :when_requested
  end

  # ========================================
  # Domain Execution
  # ========================================

  execution do
    # Default timeout for operations
    timeout 30_000

    # Trace all operations for observability
    trace_type :detailed
  end
end
