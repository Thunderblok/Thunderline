old

# ========================================
# THUNDERLINE Core Configuration
# ========================================
# "Not just an app. A substrate for evolution."

# Application Identity
config :thunderline,
  app_name: "Thunderline",
  version: "0.1.0",
  description: "Modular BEAM-powered AI-human collaboration platform",

  # Core Features
  features: [
    :pacs,           # Personal Autonomous Creations
    :ticks,          # Fault-tolerant evolution cycles
    :mcp,            # Model Context Protocol interface
    :memory,         # Semantic memory and vector lookup
    :agents,         # Jido AI agent integration
    :federation      # Bonfire federated networking (optional)
  ]

# ========================================
# Repository & Database
# ========================================
config :thunderline, Thunderline.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("POSTGRES_DB", "thunderline_dev"),
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  port: String.to_integer(System.get_env("POSTGRES_PORT", "5432")),
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),

  # Enable pgvector for semantic search
  after_connect: {Postgrex, :query!, ["CREATE EXTENSION IF NOT EXISTS vector", []]}

# ========================================
# Ash Framework Configuration
# ========================================
config :thunderline, :ash,
  domains: [Thunderline.Domain],
  apis: [Thunderline.API]

# ========================================
# Oban Job Processing (PAC Ticks)
# ========================================
config :thunderline, Oban,
  repo: Thunderline.Repo,
  plugins: [
    # Reliable job processing
    Oban.Plugins.Pruner,
    Oban.Plugins.Cron,
    Oban.Plugins.Lifeline,

    # Web dashboard for monitoring
    {Oban.Plugins.Web, [
      name: Oban.Web,
      port: 4001,
      path: "/oban"
    ]}
  ],
  queues: [
    # PAC tick processing - core evolution loop
    pacs: [limit: 50, paused: false],

    # Memory operations - embeddings, clustering
    memory: [limit: 10, paused: false],

    # MCP tool execution - agent actions
    tools: [limit: 25, paused: false],

    # Background maintenance
    maintenance: [limit: 5, paused: false]
  ],

  # Cron jobs for regular maintenance
  crontab: [
    # Memory garbage collection every hour
    {"0 * * * *", Thunderline.Memory.GarbageCollector},

    # PAC health checks every 15 minutes
    {"*/15 * * * *", Thunderline.PAC.HealthChecker},

    # System metrics collection every 5 minutes
    {"*/5 * * * *", Thunderline.Telemetry.MetricsCollector}
  ]

# ========================================
# Jido AI Agent Configuration
# ========================================
config :thunderline, :jido,
  # Agent supervision strategy
  supervisor_name: Thunderline.JidoSupervisor,

  # Default agent configuration
  default_agent_config: %{
    memory_limit: 1000,      # Max memories per PAC
    tick_timeout: 30_000,    # 30 second tick timeout
    retry_attempts: 3,       # Retry failed ticks
    reasoning_model: :local  # Use local vs remote LLM
  },

  # Agent discovery and registration
  agent_registry: Thunderline.AgentRegistry

# ========================================
# Model Context Protocol (MCP) Server
# ========================================
config :thunderline, Thunderline.MCP.Server,
  port: String.to_integer(System.get_env("MCP_PORT", "8080")),
  host: System.get_env("MCP_HOST", "localhost"),

  # Tool discovery and routing
  tool_registry: Thunderline.MCP.ToolRegistry,

  # Authentication for external agents
  auth_required: true,
  jwt_secret: System.get_env("JWT_SECRET", "dev_secret_key_change_in_production"),

  # Session management
  session_timeout: 3_600_000,  # 1 hour
  max_concurrent_sessions: 100

# ========================================
# Memory & Vector Search
# ========================================
config :thunderline, :memory,
  # Vector database configuration
  vector_dimensions: 384,      # Sentence transformers embedding size
  similarity_threshold: 0.7,   # Minimum similarity for recall
  max_memories_per_pac: 1000,  # Memory limit per PAC

  # Embedding generation
  embedding_model: "all-MiniLM-L6-v2",
  embedding_batch_size: 32,

  # Memory clustering and organization
  cluster_on_insert: true,
  reindex_interval: 3600,  # Rebuild index every hour

  # Memory lifecycle
  memory_ttl: 7 * 24 * 3600,  # 7 days default TTL
  archival_enabled: true

# ========================================
# Prompt Template System
# ========================================
config :thunderline, :prompts,
  # Template directory
  template_dir: Path.join([File.cwd!(), "prompts"]),

  # Template versioning and A/B testing
  versioning_enabled: true,
  default_version: "v1.0",

  # Template categories
  categories: [
    :pac_interaction,     # PAC-to-PAC conversations
    :npc_narration,      # Environment and NPC dialogue
    :tick_summary,       # Tick event summarization
    :memory_recall,      # Memory retrieval prompts
    :decision_making,    # PAC reasoning prompts
    :world_building      # Environment generation
  ],

  # Dynamic template compilation
  compile_on_startup: true,
  hot_reload_in_dev: true

# ========================================
# Telemetry & Monitoring
# ========================================
config :thunderline, :telemetry,
  # Core metrics to track
  metrics: [
    # PAC lifecycle metrics
    "thunderline.pac.ticks.duration",
    "thunderline.pac.ticks.count",
    "thunderline.pac.evolution.complexity",

    # Memory system metrics
    "thunderline.memory.retrieval.duration",
    "thunderline.memory.similarity.score",
    "thunderline.memory.embeddings.generated",

    # MCP tool metrics
    "thunderline.mcp.tools.invoked",
    "thunderline.mcp.tools.duration",
    "thunderline.mcp.sessions.active",

    # System health metrics
    "thunderline.system.cpu.usage",
    "thunderline.system.memory.usage",
    "thunderline.database.connections.active"
  ],

  # Event dispatch configuration
  events: [
    [:thunderline, :pac, :tick, :start],
    [:thunderline, :pac, :tick, :stop],
    [:thunderline, :pac, :evolution, :complete],
    [:thunderline, :memory, :recall, :start],
    [:thunderline, memory, :recall, :stop],
    [:thunderline, :mcp, :tool, :invoke],
    [:thunderline, :agent, :reasoning, :complete]
  ]

# ========================================
# Web Interface (Optional)
# ========================================
config :thunderline, :web,
  # Enable web interface for monitoring and interaction
  enabled: System.get_env("WEB_ENABLED", "true") == "true",
  port: String.to_integer(System.get_env("WEB_PORT", "4000")),

  # Dashboard features
  dashboard: [
    :pacs,          # PAC management interface
    :ticks,         # Tick monitoring and logs
    :memory,        # Memory browser and search
    :agents,        # Agent status and configuration
    :tools,         # MCP tool registry and invocation
    :telemetry      # Real-time metrics and alerts
  ]

# ========================================
# Development & Testing
# ========================================
if config_env() == :dev do
  config :thunderline,
    # Enhanced logging and debugging
    log_level: :debug,
    log_sql_queries: true,

    # Hot reloading for prompts and templates
    hot_reload_prompts: true,

    # Development seeds and fixtures
    seed_development_data: true,
    create_demo_pacs: 5,

    # Relaxed security for development
    jwt_verification_strict: false
end

if config_env() == :test do
  config :thunderline,
    # Fast testing configuration
    pool_size: 2,
    log_level: :warn,

    # Test-specific overrides
    tick_processing: :manual,  # Manual tick processing in tests
    memory_persistence: :ets,  # In-memory for faster tests
    external_api_calls: :mock  # Mock external LLM calls
end

# ========================================
# Runtime Configuration
# ========================================
# Note: Sensitive configuration should be set in runtime.exs
# using environment variables for production deployment
