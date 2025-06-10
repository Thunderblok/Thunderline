import Config

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.

# Configure production database
config :thunderline, Thunderline.Repo,
  # ssl: true,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

# Configure the endpoint for production
config :thunderline, ThunderlineWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Swoosh API client is only required for production adapters.
config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Configure Oban for production
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
    mcp: 15,
    background: 5
  ]
