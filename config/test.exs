import Config

config :thunderline, Thunderline.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "thunderline_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :thunderline, ThunderlineWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "TEST_SECRET_KEY_BASE_CHANGE_IN_PRODUCTION",
  server: false

# In test we don't send emails.
config :swoosh, :api_client, false

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Configure Oban for testing
config :thunderline, Oban, testing: :inline

# Disable MCP server in tests
config :thunderline, :mcp,
  enabled: false,
  port: 3002

# Test AI configuration
config :thunderline, :ai,
  openai_api_key: "test_key",
  default_model: "gpt-3.5-turbo",
  embedding_model: "text-embedding-ada-002"

# Fast tick interval for testing
config :thunderline, :pac,
  tick_interval: 1000,  # 1 second
  default_zone_size: 10,
  max_agents_per_zone: 5
