import Config

# Configure Ecto repositories
config :thunderline, ecto_repos: [Thunderline.Repo]

# Configure your database
config :thunderline, Thunderline.Repo,
  adapter: Ecto.Adapters.Postgres,
  migration_timestamps: [type: :utc_datetime_usec]

# Configures the endpoint
config :thunderline, ThunderlineWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ThunderlineWeb.ErrorHTML, json: ThunderlineWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Thunderline.PubSub,
  live_view: [signing_salt: "kBKjkGGw"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Ash
config :ash, :validate_domain_resource_inclusion?, false
config :ash, :validate_domain_config_inclusion?, false

# Configure Ash Authentication
config :ash_authentication, :authentication,
  providers: [
    password: [
      identity_field: :email,
      hashed_password_field: :hashed_password,
      hash_provider: AshAuthentication.BcryptProvider,
      confirmation_required?: false
    ]
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Import local config if it exists (for secrets, etc.)
if File.exists?("config/local.exs") do
  import_config "local.exs"
end
