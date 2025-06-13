# ☤ THUNDERLINE SOVEREIGN SUBSTRATE - README ☤

**Autonomous AI Agent Federation Platform**  
**Status**: ✅ **OPERATIONAL - SPATIAL TRACKING IN PROGRESS** ☤  
**Version**: 2.0.0-spatial  
**Last Updated**: June 13, 2025

---

## 🎯 **WHAT IS THUNDERLINE?**

Thunderline is a **sovereign AI agent substrate** that enables the creation, coordination, and evolution of Personal Autonomous Creations (PACs) across a federated network. Think of it as a distributed operating system for AI agents, where each PAC can think, learn, and interact autonomously while contributing to a larger collective intelligence.

### **Core Capabilities**
- **🤖 Autonomous Agents**: PACs with personality, memory, and reasoning capabilities
- **🌐 Federation Ready**: Multi-node coordination with spatial awareness
- **🧠 Vector Memory**: Semantic search and graph relationships
- **⚡ Real-time Processing**: High-throughput tick-based evolution
- **🛠️ Tool Integration**: Dynamic capability expansion via MCP protocol
- **📊 Spatial Tracking**: 3D world position coordination (in progress)

### **Strategic Value**
- **Complete Sovereignty**: Zero external dependencies
- **Unlimited Scalability**: Horizontal scaling across nodes
- **Advanced AI Integration**: GPT-4+ reasoning with tool use
- **Production Ready**: Enterprise-grade reliability and performance

---

## 🚀 Quick Start

Thunderline is a modular AI-human collaboration substrate featuring autonomous PAC (Personal Autonomous Creation) agents with neural memory systems, spatial zone management, and evolution tracking. The system has been successfully refactored to a sovereign AgentCore architecture with all major compilation errors resolved.

### **Key Features** ☤
- 🤖 **PAC Agent System**: Sovereign autonomous reasoning agents with AgentCore
- 🧠 **Neural Memory**: Graph-based memory nodes with vector embeddings  
- 📍 **Zone Management**: Spatial containers for agent organization
- ⏰ **Tick Pipeline**: Broadway-based evolution tracking and decision logging
- 🔧 **Mod System**: Dynamic agent enhancement capabilities
- 🌐 **World Position Coordination**: Real-time 3D spatial tracking (implementing)
- 🎯 **Governor Network**: Regional coordination for multi-agent systems

### **Recent Achievements** ☤
- ✅ **Clean Compilation**: All Ash DSL syntax errors resolved
- ✅ **Database Compatibility**: PostgreSQL `:gin` index issues fixed
- ✅ **Caduceus Integration**: Professional branding across codebase
- ✅ **AgentCore Architecture**: Refactored from Jido dependencies
- ✅ **Warning Elimination**: Logger deprecations and type issues resolved

Thunderline is a standalone application for building and running autonomous AI agents in a persistent, evolving environment. It provides a complete substrate for:

- **PAC (Perception-Action-Cognition) Agents**: Autonomous entities with personality, memory, and evolving capabilities
- **Model Context Protocol (MCP)**: Standardized interface for AI agent tool interaction
- **Memory Graph System**: Persistent, searchable memory with vector embeddings and graph relationships
- **Tick-Based Simulation**: Coordinated agent evolution and interaction with Broadway pipeline
- **Zone Management**: Spatial and conceptual environments for agents
- **World Position Coordination**: 3D spatial tracking with bi-tick sync cadence

## Features

### 🤖 PAC Agent Framework
- Autonomous agents with stats, traits, and evolving state
- Personality-driven behavior and decision making via AgentCore
- Mod system for capability enhancement
- Tick-based lifecycle management with Broadway processing
- **NEW**: 3D position tracking and spatial awareness

### 🧠 Advanced Memory System
- Vector embeddings for semantic memory search (pgvector enabled)
- Graph-based memory relationships with MemoryEdge connections
- Automatic memory consolidation and pruning
- Multi-modal memory types (episodic, semantic, procedural, emotional)

### 🔧 Model Context Protocol (MCP)
- Standardized tool interface for AI agents
- WebSocket-based communication
- Extensible tool registry with schema validation
- Session management and authentication

### 🌍 Spatial Environment
- Zone-based agent organization with capacity management
- Environmental properties and rules
- Resource management and scarcity
- **NEW**: Regional Governor nodes for spatial coordination
- Agent interaction boundaries

### ⚡ High Performance
- Built on Phoenix/Elixir for massive concurrency
- Ash framework for data modeling and APIs
- Oban for background job processing
- PostgreSQL with vector extensions

## Quick Start

### Prerequisites

- Elixir 1.15+
- PostgreSQL 14+ with vector extension
- Node.js 18+ (for assets)

### Installation

1. **Clone and setup**
   ```bash
   git clone <repository-url>
   cd thunderline-standalone
   mix deps.get
   ```

2. **Database setup**
   ```bash
   mix ecto.setup
   ```

3. **Start the server**
   ```bash
   mix phx.server
   ```

4. **Visit the application**
   - Web interface: http://localhost:4000
   - MCP server: ws://localhost:3001
   - API documentation: http://localhost:4000/json_api

### Environment Variables

```bash
# Database
DATABASE_URL=ecto://postgres:postgres@localhost/thunderline_dev

# AI Configuration
OPENAI_API_KEY=your_openai_api_key
DEFAULT_AI_MODEL=gpt-4-turbo-preview
EMBEDDING_MODEL=text-embedding-3-small

# MCP Configuration
MCP_ENABLED=true
MCP_PORT=3001

# PAC System
PAC_TICK_INTERVAL=30000  # milliseconds
DEFAULT_ZONE_SIZE=100
MAX_AGENTS_PER_ZONE=50
```

## Usage

### Creating Your First Agent

```elixir
# Create a zone
{:ok, zone} = Thunderline.PAC.Zone.create("test_zone")

# Create an agent
{:ok, agent} = Thunderline.PAC.Manager.create_agent(
  "alice", 
  zone.id,
  description: "A curious AI agent"
)

# Check agent status
{:ok, agent_info} = Thunderline.PAC.Manager.get_agent(agent.id)
```

### Using MCP Tools

```elixir
# List available tools
{:ok, tools} = Thunderline.MCP.ToolRegistry.list_tools()

# Call a tool
{:ok, result} = Thunderline.MCP.ToolRegistry.call_tool(
  "pac_get_agent",
  %{"agent_id" => agent.id}
)
```

### Memory Operations

```elixir
# Store a memory
{:ok, memory} = Thunderline.Memory.Manager.store(
  agent.id,
  "I learned something interesting today",
  tags: ["learning", "insight"]
)

# Search memories
{:ok, results} = Thunderline.Memory.Manager.search(
  agent.id,
  "learning experiences",
  limit: 5
)
```

## API Reference

### REST API

The application provides a JSON:API compliant REST interface:

- **PAC Agents**: `/json_api/pac_agents`
- **Zones**: `/json_api/pac_zones`
- **Mods**: `/json_api/pac_mods`
- **Memory Nodes**: `/json_api/memory_nodes`
- **Memory Edges**: `/json_api/memory_edges`

### MCP Interface

WebSocket endpoint at `/mcp` provides:

- Tool discovery and execution
- Session management
- Real-time agent interaction
- Event streaming

### GraphQL (Future)

GraphQL endpoint planned for complex queries and subscriptions.

## Architecture

### Core Systems

1. **PAC Manager**: Coordinates agent lifecycle and interactions
2. **Memory Manager**: Handles memory storage, search, and graph operations
3. **MCP Server**: Provides tool interface for AI integration
4. **Tick Orchestrator**: Manages simulation time and agent updates
5. **Zone System**: Spatial organization and environmental simulation

### Data Flow

```
AI Client (via MCP) → Tool Registry → PAC Manager → Agent
                                   ↓
Memory Manager ← Tick Orchestrator ← Zone System
```

### Technology Stack

- **Phoenix**: Web framework and real-time features
- **Ash**: Resource modeling and API generation
- **Ecto**: Database ORM with PostgreSQL
- **Oban**: Background job processing
- **pgvector**: Vector similarity search
- **Finch**: HTTP client for AI APIs
- **Jason**: JSON encoding/decoding

## Development

### Running Tests

```bash
mix test
```

### Database Operations

```bash
# Create migration
mix ecto.gen.migration create_new_table

# Run migrations
mix ecto.migrate

# Reset database
mix ecto.reset
```

### Code Quality

```bash
# Format code
mix format

# Run static analysis
mix credo

# Type checking
mix dialyzer
```

## Deployment

### Docker

```dockerfile
# Dockerfile included for containerized deployment
docker build -t thunderline .
docker run -p 4000:4000 thunderline
```

### Production Configuration

See `config/runtime.exs` for production environment variables.

### Database Setup

Ensure PostgreSQL has required extensions:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the AGPL-3.0 License - see the LICENSE file for details.

## Support

- Documentation: [Coming Soon]
- Issues: [GitHub Issues]
- Discussions: [GitHub Discussions]

---

**Thunderline** - Building the future of autonomous AI agents, one tick at a time.
