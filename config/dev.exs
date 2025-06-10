import Config

# Configure your database
config :thunderline, Thunderline.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "thunderline_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Configure the endpoint
config :thunderline, ThunderlineWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "CHANGE_ME_IN_PRODUCTION",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :thunderline, ThunderlineWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/thunderline_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :thunderline, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Include HEEx debug annotations as HTML comments in rendered markup
config :phoenix_live_view, :debug_heex_annotations, true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Configure Oban for development
config :thunderline, Oban,
  repo: Thunderline.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron, crontab: [
      {"*/30 * * * *", Thunderline.Tick.TickWorker}
    ]}
  ],
  queues: [
    tick: 10,
    memory: 5,
    agents: 20,
    mcp: 15
  ]

# AI Configuration - use environment variables or override in local config
config :thunderline, :ai,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  default_model: "gpt-4-turbo-preview",
  embedding_model: "text-embedding-3-small"

# MCP Configuration
config :thunderline, :mcp,
  port: 3001,
  tools_config_path: "config/mcp_tools.json"

# PAC Configuration
config :thunderline, :pac,
  tick_interval: 30_000,  # 30 seconds
  default_zone_size: 100,
  max_agents_per_zone: 50

# Memory Configuration
config :thunderline, :memory,
  vector_dimensions: 1536,
  similarity_threshold: 0.7,
  max_memory_nodes: 10000
