defmodule Thunderline.Application do
  @moduledoc """
  Thunderline Application - A modular, BEAM-powered AI-human collaboration platform.

  Not just an app. A substrate for evolution.

  This application orchestrates:
  - Ash Framework: Declarative PACs, Mods, Zones as first-class resources
  - Oban: Fault-tolerant tick loops driving PAC cycles
  - Jido AI: Memory-bound agent reasoning with MCP integration
  - Postgres + pgvector: Memory, semantic lookup, tick logging
  - JSON-over-socket MCP: Standardized agent-tool interface
  """

  use Application

  alias Thunderline.{Repo, Supervisor}

  @impl true
  def start(_type, _args) do
    children = [
      # Database
      Thunderline.Repo,

      # Telemetry supervisor
      ThunderlineWeb.Telemetry,

      # PubSub system
      {Phoenix.PubSub, name: Thunderline.PubSub},

      # Oban for job processing (PAC tick cycles)
      {Oban, oban_config()},

      # Jido supervisor for AI agents
      {Jido.Supervisor, name: Thunderline.JidoSupervisor},

      # Ash resources supervisor
      {AshPostgres.Repo, Thunderline.Repo},

      # Main Thunderline supervisor
      Thunderline.Supervisor,

      # Web endpoint (if enabled)
      maybe_web_endpoint()
    ]
    |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: Thunderline.Application.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Configuration

  defp oban_config do
    Application.fetch_env!(:thunderline, Oban)
  end

  defp maybe_web_endpoint do
    if Application.get_env(:thunderline, :start_web, true) do
      ThunderlineWeb.Endpoint
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ThunderlineWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
