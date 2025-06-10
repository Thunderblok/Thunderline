import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

# Database configuration
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :thunderline, Thunderline.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :thunderline, ThunderlineWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # AI configuration from environment
  config :thunderline, :ai,
    openai_api_key: System.get_env("OPENAI_API_KEY"),
    default_model: System.get_env("DEFAULT_AI_MODEL") || "gpt-4-turbo-preview",
    embedding_model: System.get_env("EMBEDDING_MODEL") || "text-embedding-3-small"

  # MCP configuration
  config :thunderline, :mcp,
    enabled: System.get_env("MCP_ENABLED") != "false",
    port: String.to_integer(System.get_env("MCP_PORT") || "3001")

  # PAC configuration
  config :thunderline, :pac,
    tick_interval: String.to_integer(System.get_env("PAC_TICK_INTERVAL") || "30000"),
    default_zone_size: String.to_integer(System.get_env("DEFAULT_ZONE_SIZE") || "100"),
    max_agents_per_zone: String.to_integer(System.get_env("MAX_AGENTS_PER_ZONE") || "50")
end

# Swoosh configuration
if config_env() == :prod do
  config :swoosh,
    api_client: Swoosh.ApiClient.Finch,
    finch_name: Thunderline.Finch

  # Email configuration would go here
  # config :thunderline, Thunderline.Mailer,
  #   adapter: Swoosh.Adapters.Postmark,
  #   api_key: System.get_env("POSTMARK_API_KEY")
end
