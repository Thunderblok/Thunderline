# ☤ Thunderline Application - Sovereign AI Agent Substrate
defmodule Thunderline.Application do
  @moduledoc """
  The Thunderline Application - A sovereign AI agent substrate. ☤

  Thunderline is a standalone Phoenix/Ash/Oban application that provides:
  - PAC (Perception-Action-Cognition) agent framework
  - Model Context Protocol (MCP) server capabilities
  - Tick-based simulation engine
  - Memory and narrative management
  - Multi-agent coordination
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Telemetry setup
      ThunderlineWeb.Telemetry,

      # Database
      Thunderline.Repo,

      # PubSub
      {Phoenix.PubSub, name: Thunderline.PubSub},

      # Finch HTTP client
      {Finch, name: Thunderline.Finch},

      # Job processing
      {Oban, Application.fetch_env!(:thunderline, Oban)},

      # Ash resources
      {AshAuthentication.Supervisor, otp_app: :thunderline},

      # Core Thunderline subsystems
      Thunderline.Supervisor,

      # Web endpoint
      ThunderlineWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Thunderline.ApplicationSupervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ThunderlineWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
