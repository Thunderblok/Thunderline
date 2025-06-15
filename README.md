# ☤ Thunderline: AI Agent Development Platform

> **Elixir/Phoenix foundation for autonomous AI agents**

**Status**: 🔧 **ACTIVE DEVELOPMENT** - Core architecture complete, features in progress  
**Version**: 0.3.0-dev  
**Last Updated**: June 15, 2025

---

## 🎯 What is Thunderline?

Thunderline is a **development platform** for creating autonomous AI agents (PACs - Personal Autonomous Creations) using modern Elixir/Phoenix architecture. Think of it as a substrate where AI agents can live, learn, and interact with each other and the world through tools.

### Current Capabilities ✅
- **🤖 PAC Agent Framework**: Basic agent creation and management via Ash resources
- **🧠 Memory System**: Vector embeddings + graph relationships for agent memories  
- **⚡ Tick Processing**: Broadway/Oban pipeline for concurrent agent evolution
- **🛠️ Tool Integration**: MCP (Model Context Protocol) for AI-environment interaction
- **📊 Web Dashboard**: Phoenix LiveView monitoring interface (basic)
- **🔗 Ash AI Integration**: Prompt-backed actions and Reactor pipeline (experimental)

### In Development 🔧
- **Agent reasoning flows**: Complete AI decision-making pipeline
- **Memory integration**: Full tick-to-memory persistence  
- **Advanced dashboard**: Real-time agent monitoring and control
- **Spatial awareness**: 3D world position tracking for agents
- **Federation**: Multi-node agent coordination

---
- ✅ **Caduceus Integration**: Professional branding across codebase
- ✅ **AgentCore Architecture**: Refactored from Jido dependencies
- ✅ **Warning Elimination**: Logger deprecations and type issues resolved
>>>>>>> 212c31da4e9706490626ecae353f8378e49f0d18

**Status**: ✅ **READY FOR AI DEV TEAM TAKEOVER** ☤  
**Phase**: Integration Implementation Ready  
**Last Updated**: June 14, 2025

Thunderline is a production-ready platform for building and running autonomous AI agents with real-time monitoring. Following comprehensive research analysis, it provides:

- **PAC (Perception-Action-Cognition) Agents**: Autonomous entities with personality, memory, and evolving capabilities
- **Real-Time Dashboard**: Phoenix LiveView monitoring with live agent status updates
- **Memory Integration**: Vector embeddings + semantic search for agent experiences
- **Tick Processing Pipeline**: Broadway + Oban for concurrent agent evolution
- **Narrative Engine**: Human-readable stories of agent decisions and actions
- **Model Context Protocol (MCP)**: Standardized interface for AI agent tool interaction
<<<<<<< HEAD
=======
## 🚀 Quick Setup (5 minutes)

### Prerequisites
- Elixir 1.15+ and OTP 25+
- PostgreSQL 14+ with pgvector extension
- Node.js 18+ (for assets)

### Installation
```bash
# 1. Install dependencies
mix deps.get

# 2. Setup database
mix ecto.setup

# 3. Start the server
mix phx.server
```

### Verify Installation
- 🌐 **Web UI**: http://localhost:4000
- 📊 **PAC Dashboard**: http://localhost:4000/pac_dashboard  
- 🔧 **LiveDashboard**: http://localhost:4000/dev/dashboard
- 🛠️ **MCP Server**: ws://localhost:3001

---

## 🏗️ Architecture Overview

### Core Components
```
Thunderline.Application (OTP Supervisor)
├── Thunderline.Repo (PostgreSQL + pgvector)
├── Thunderline.Domain (Ash resources)
├── Thunderline.PAC.* (Agent system)
├── Thunderline.Memory.* (Vector + graph memory)
├── Thunderline.Tick.* (Broadway pipeline)
├── Thunderline.MCP.* (Tool integration)
└── ThunderlineWeb.* (Phoenix LiveView UI)
```

### Technology Stack
- **🔥 Elixir/OTP**: Fault-tolerant, concurrent runtime
- **� Phoenix 1.7**: Web framework with LiveView
- **⚡ Ash Framework**: Resource modeling and APIs
- **🗄️ PostgreSQL**: Primary database with vector search
- **� Oban/Broadway**: Job processing and streaming
- **🤖 Ash AI**: Prompt-backed actions (experimental)
- **⚛️ Reactor**: Declarative workflow orchestration

---

## 💡 Development Status

### What's Working ✅
- **Core Foundation**: Phoenix app starts and runs
- **Database Layer**: All Ash resources defined and migrated
- **Basic Web UI**: LiveView dashboard foundation by Jules/UI team
- **Agent Framework**: PAC agents can be created and managed
- **Memory System**: Vector storage and graph relationships
- **Tool Integration**: MCP protocol and WebSocket server

### In Progress 🔧
- **Agent Reasoning**: Ash AI + Reactor pipeline integration
- **Memory Integration**: Full tick-to-memory persistence
- **Web Dashboard**: Advanced monitoring and control features
- **Spatial System**: 3D world position tracking

### Coming Soon 📋
- **Production Polish**: Error handling, testing, performance
- **Advanced Features**: Federation, narrative engine, AI reasoning
- **Documentation**: API docs, deployment guides

---

## 📚 Documentation & Development

For comprehensive development information, see the [`docs/`](docs/) directory:

- **[📖 Development Guide](docs/DEVELOPMENT_GUIDE.md)** - Implementation framework and examples
- **[📋 Kanban Board](docs/KANBAN_BOARD.md)** - Sprint planning and task breakdown  
- **[🏗️ Architecture](docs/ARCHITECTURE_COMPLETE.md)** - Technical deep dive
- **[📊 Project Status](docs/PROJECT_ROADMAP.md)** - Strategic roadmap and status

---

## 🤝 Contributing

This is an active development project. Key areas needing work:

1. **Agent AI Integration** - Complete the Ash AI + Reactor pipeline
2. **Memory System** - Ensure tick-to-memory persistence works
3. **Web Dashboard** - Enhance the LiveView monitoring interface
4. **Testing** - Add comprehensive test coverage
5. **Documentation** - API documentation and deployment guides

See [Development Guide](docs/DEVELOPMENT_GUIDE.md) for detailed setup and contribution instructions.

---

## 📄 License

[Add license information here]

---

*Built with ☤ by the Thunderline development team*

# 3. Start server
mix phx.server
```

### Verification
- Server: http://localhost:4000
- MCP server: ws://localhost:3001
- API docs: http://localhost:4000/json_api

**For complete setup instructions**: See [Development Guide](docs/DEVELOPMENT_GUIDE.md)

## 📊 Current Status


**📋 Project Status**: READY FOR AI DEVELOPMENT TEAM EXECUTION  
**🎯 Mission**: Complete integration of agents, memory, and real-time dashboard  
**⚡ Confidence Level**: HIGH - All requirements defined with clear implementation paths  

☤ **Thunderline: Building the future of autonomous AI agents** ☤
