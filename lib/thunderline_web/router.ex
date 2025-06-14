defmodule ThunderlineWeb.Router do
  use ThunderlineWeb, :router
  # use AshAuthentication.Phoenix.Router # Commented out until authentication is properly configured
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ThunderlineWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # plug :load_from_session # Commented out until authentication is configured
  end

  pipeline :api do
    plug :accepts, ["json"]
    # plug :load_from_bearer # Commented out until authentication is configured
  end
  scope "/", ThunderlineWeb do
    pipe_through :browser

    get "/", PageController, :home

    # OKO GridWorld Map
    live "/map", MapLive, :index
    live "/map/:region", MapLive, :region

    # Authentication routes - commented out until properly configured
    # auth_routes AuthController, Thunderline.Accounts.User, path: "/auth"
    # sign_out_route AuthController

    # Reset password - commented out until properly configured
    # reset_route []
  end

  # API routes
  scope "/api", ThunderlineWeb do
    pipe_through :api

    # PAC Agent API
    scope "/pac" do
      post "/agents", PACController, :create_agent
      get "/agents/:id", PACController, :get_agent
      put "/agents/:id", PACController, :update_agent
      post "/agents/:id/tick", PACController, :tick_agent
    end

    # Memory API
    scope "/memory" do
      post "/search", MemoryController, :search
      post "/store", MemoryController, :store
      get "/graph/:agent_id", MemoryController, :get_graph
    end

    # MCP API
    scope "/mcp" do
      post "/tools", MCPController, :list_tools
      post "/tools/:name/call", MCPController, :call_tool
    end

    # Tick system API
    scope "/tick" do
      get "/status", TickController, :status
      post "/start", TickController, :start_simulation
      post "/stop", TickController, :stop_simulation
    end
  end

  # Live Dashboard for development
  if Application.compile_env(:thunderline, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ThunderlineWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # JSON API for Ash resources
  scope "/json_api" do
    pipe_through :api

    forward "/", AshJsonApi.Router,
      domains: [Thunderline.Domain],
      json_schema: "/json_schema"
  end
end
