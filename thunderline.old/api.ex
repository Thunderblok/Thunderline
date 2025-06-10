defmodule Thunderline.API do
  @moduledoc """
  Thunderline API - REST and programmatic interface for Thunderline operations.

  This API provides access to all Thunderline functionality:
  - PAC creation, management, and evolution
  - Zone exploration and modification
  - Memory storage and retrieval
  - Tick monitoring and debugging
  - Agent configuration and control

  Built on Ash.Api for automatic REST endpoint generation,
  validation, and declarative operation definitions.
  """

  use Ash.Api

  # ========================================
  # API Configuration
  # ========================================

  # Include all domain resources
  resources do
    registry Thunderline.Domain
  end

  # ========================================
  # API Authorization
  # ========================================

  authorization do
    # Authorize based on actor context
    authorize :when_requested

    # Default actor from session or JWT
    actor_from_request Thunderline.Auth.actor_from_request()
  end

  # ========================================
  # API Execution Context
  # ========================================

  execution do
    # Default timeout for API operations
    timeout 30_000

    # Detailed tracing for debugging
    trace_type :detailed

    # Transaction isolation level
    transaction_isolation_level :read_committed
  end
end
