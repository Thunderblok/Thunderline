# 🔧 THUNDERLINE Development Guide

## 🚀 Quick Start

### Prerequisites
- Elixir 1.15+
- PostgreSQL with pgvector extension
- Node.js 18+ (for tooling)

### Environment Setup
```bash
# Clone and setup
git clone <repository>
cd Thunderline

# Install dependencies
mix deps.get

# Setup database
mix ecto.setup

# Start development server
mix phx.server
```

### Environment Variables
```bash
# Copy example environment
cp .env.example .env

# Required variables:
DATABASE_URL=postgresql://user:pass@localhost/thunderline_dev
OPENAI_API_KEY=your_api_key_here
OPENAI_BASE_URL=https://api.openai.com/v1
```

## 🏗️ Development Workflow

### 1. Creating New PACs
```elixir
# Create a PAC using Ash
{:ok, pac} = Thunderline.PAC.create(%{
  name: "Alice",
  stats: %{"curiosity" => 75, "creativity" => 85},
  traits: ["analytical", "creative"],
  state: %{"energy" => 100, "mood" => "curious"}
})
```

### 2. Adding New MCP Tools
```elixir
# 1. Create tool module
defmodule Thunderline.MCP.Tools.YourTool do
  @behaviour Thunderline.MCP.Tool
  
  def execute(inputs, context) do
    # Tool implementation
    {:ok, result}
  end
end

# 2. Register with registry (automatic for built-ins)
Thunderline.MCP.ToolRegistry.register_tool(%{
  name: "your_tool",
  description: "What your tool does",
  category: "category",
  module: Thunderline.MCP.Tools.YourTool,
  input_schema: %{
    type: "object",
    required: ["param1"],
    properties: %{
      "param1" => %{type: "string", description: "Parameter description"}
    }
  }
})
```

### 3. Creating Custom Actions
```elixir
defmodule Thunderline.Agents.Actions.YourAction do
  use Jido.Action,
    name: "your_action",
    description: "Action description",
    schema: [
      param1: [type: :string, required: true],
      param2: [type: :integer, default: 0]
    ]
  
  @impl true
  def run(params, context) do
    # Action implementation
    {:ok, result}
  end
end
```

### 4. Testing PAC Ticks
```elixir
# Create test PAC
{:ok, pac} = Thunderline.PAC.create(%{
  name: "TestPAC",
  stats: %{"intelligence" => 70},
  traits: ["curious"]
})

# Execute tick manually
job_args = %{pac_id: pac.id, tick_number: 1}
Thunderline.Tick.TickWorker.perform(%Oban.Job{args: job_args})
```

## 🧪 Testing

### Running Tests
```bash
# All tests
mix test

# Specific test
mix test test/integration/pac_tick_test.exs

# With coverage
mix test --cover
```

### Test Structure
```
test/
├── integration/           # End-to-end tests
├── thunderline/
│   ├── agents/           # Agent action tests
│   ├── mcp/              # Tool system tests
│   ├── memory/           # Memory system tests
│   ├── pac/              # PAC resource tests
│   └── tick/             # Tick pipeline tests
└── support/              # Test helpers
```

### Writing Tests
```elixir
defmodule Thunderline.YourModuleTest do
  use Thunderline.DataCase
  
  alias Thunderline.YourModule
  
  test "does something useful" do
    result = YourModule.do_something()
    assert result == :expected
  end
end
```

## 🔍 Debugging

### IEx Debugging
```elixir
# Start IEx with app
iex -S mix

# Common debugging commands
iex> Thunderline.PAC |> Thunderline.Repo.all()
iex> Thunderline.MCP.ToolRegistry.get_all_tools()
iex> Oban.queue()
```

### Logging
```elixir
# Add to your modules
require Logger

Logger.debug("Debug information")
Logger.info("General information")
Logger.warning("Warning message")
Logger.error("Error occurred")
```

### Performance Monitoring
```bash
# Observer for system monitoring
iex> :observer.start()

# Memory usage
iex> :erlang.memory()

# Process count
iex> length(Process.list())
```

## 📦 Dependencies

### Core Dependencies
- **ash**: Declarative resource framework
- **oban**: Background job processing
- **jido**: Agent framework
- **pgvector**: Vector similarity search
- **phoenix**: Web framework (optional)

### AI Dependencies
- **openai**: OpenAI API client
- **jason**: JSON encoding/decoding
- **req**: HTTP client

### Development Dependencies
- **credo**: Code analysis
- **dialyzer**: Type checking
- **ex_doc**: Documentation generation

## 🚀 Deployment

### Production Configuration
```elixir
# config/prod.exs
config :thunderline, Thunderline.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :thunderline,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  openai_base_url: System.get_env("OPENAI_BASE_URL")
```

### Database Migration
```bash
# Run migrations
mix ecto.migrate

# Create new migration
mix ecto.gen.migration add_new_field
```

### Release Building
```bash
# Build release
mix release

# Start release
_build/prod/rel/thunderline/bin/thunderline start
```

## 🔧 Configuration

### Application Configuration
```elixir
# config/thunderline.exs
config :thunderline,
  # AI Provider settings
  ai_provider: :openai,
  default_model: "gpt-3.5-turbo",
  max_tokens: 1000,
  
  # Memory settings
  embedding_model: "text-embedding-3-small",
  memory_similarity_threshold: 0.7,
  
  # Tick settings
  tick_interval: :timer.minutes(5),
  max_concurrent_ticks: 10
```

### Environment-Specific Settings
```elixir
# config/dev.exs - Development
config :thunderline,
  debug_mode: true,
  log_level: :debug

# config/test.exs - Testing  
config :thunderline,
  ai_provider: :mock,
  async_ticks: false

# config/prod.exs - Production
config :thunderline,
  log_level: :info,
  enable_telemetry: true
```

## 🛠️ Common Tasks

### Add New Zone Type
```elixir
# 1. Add to Zone resource
defmodule Thunderline.PAC.Zone do
  # Add new zone type to enum
  attribute :zone_type, :string do
    constraints one_of: ["digital", "physical", "hybrid", "your_new_type"]
  end
end

# 2. Create migration
mix ecto.gen.migration add_new_zone_type

# 3. Update validations and business logic
```

### Create Custom Prompt Template
```elixir
# Add to prompt manager
Thunderline.MCP.PromptManager.register_template(:your_template, """
You are #{pac_name} in a #{context_type} situation.

Context: #{context}
Goal: #{goal}

Please respond with specific action recommendations.
""")
```

### Monitor System Health
```elixir
# Check tick processing
iex> Oban.queue()

# Monitor PAC states
iex> Thunderline.PAC.list() |> Enum.map(&{&1.name, &1.active})

# Memory usage
iex> Thunderline.Memory.Manager.stats()
```

## 🐛 Troubleshooting

### Common Issues

#### Database Connection Errors
```bash
# Check PostgreSQL is running
brew services status postgresql
# or
sudo systemctl status postgresql

# Verify database exists
psql -l | grep thunderline
```

#### Oban Job Failures
```elixir
# Check failed jobs
iex> Oban.queue(queue: :default, state: :failed)

# Retry failed jobs
iex> Oban.retry_job(job_id)
```

#### Memory Issues
```elixir
# Check embedding service
iex> Thunderline.Memory.VectorSearch.health_check()

# Clear memory cache
iex> Thunderline.Memory.Manager.clear_cache()
```

#### AI Provider Errors
```elixir
# Test API connection
iex> Thunderline.AI.Provider.test_connection()

# Check rate limits
iex> Thunderline.AI.Provider.get_usage()
```

### Debug Mode
```elixir
# Enable debug logging
config :logger, level: :debug

# Enable trace mode for specific modules
config :thunderline, trace_modules: [
  Thunderline.Tick.Pipeline,
  Thunderline.Agents.PACAgent
]
```

## 📖 Resources

### Documentation
- [Ash Framework](https://ash-hq.org/)
- [Jido Agent Framework](https://hexdocs.pm/jido)
- [Oban Background Jobs](https://hexdocs.pm/oban)
- [Phoenix Framework](https://phoenixframework.org/)

### Tools
- [Phoenix LiveDashboard](http://localhost:4000/dashboard) - System monitoring
- [Oban Web](http://localhost:4000/oban) - Job monitoring
- [ExUnit](https://hexdocs.pm/ex_unit) - Testing framework

### Community
- [Elixir Forum](https://elixirforum.com/)
- [Elixir Slack](https://elixir-slackin.herokuapp.com/)
- [Bonfire Networks](https://bonfirenetworks.org/)

---

Happy coding! 🚀
