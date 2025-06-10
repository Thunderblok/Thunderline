# 🔌 THUNDERLINE API Reference

## Overview

This document provides a comprehensive API reference for the Thunderline modular substrate. All APIs follow Elixir conventions and return tagged tuples for error handling.

## 📦 Core Modules

### Thunderline.PAC

Personal Autonomous Creation management.

#### `create/1`
Creates a new PAC with the given attributes.

```elixir
{:ok, pac} = Thunderline.PAC.create(%{
  name: "Alice",
  stats: %{"curiosity" => 75, "creativity" => 85},
  traits: ["analytical", "creative"],
  state: %{"energy" => 100, "mood" => "curious"}
})
```

**Parameters:**
- `name` (string, required): PAC identifier
- `stats` (map, optional): Numerical attributes
- `traits` (list, optional): Personality characteristics  
- `state` (map, optional): Current state data
- `agent_config` (map, optional): AI agent configuration

**Returns:** `{:ok, %Thunderline.PAC{}}` | `{:error, changeset}`

#### `get/1`
Retrieves a PAC by ID.

```elixir
{:ok, pac} = Thunderline.PAC.get("pac-uuid")
```

#### `update/2`
Updates PAC attributes.

```elixir
{:ok, updated_pac} = Thunderline.PAC.update(pac, %{
  stats: %{"curiosity" => 80}
})
```

#### `list/0`
Lists all PACs.

```elixir
pacs = Thunderline.PAC.list()
```

### Thunderline.PAC.Manager

PAC lifecycle management.

#### `activate_pac/1`
Activates a PAC and starts its agent.

```elixir
{:ok, agent_pid} = Thunderline.PAC.Manager.activate_pac(pac)
```

#### `deactivate_pac/1`
Deactivates a PAC and stops its agent.

```elixir
:ok = Thunderline.PAC.Manager.deactivate_pac(pac)
```

#### `assign_to_zone/2`
Assigns a PAC to a specific zone.

```elixir
{:ok, pac} = Thunderline.PAC.Manager.assign_to_zone(pac, zone)
```

### Thunderline.Agents.PACAgent

AI agent wrapper for PACs.

#### `start_pac_agent/2`
Starts a Jido agent for a PAC.

```elixir
{:ok, agent_pid} = Thunderline.Agents.PACAgent.start_pac_agent(pac, opts)
```

#### `assess_context/2`
Triggers context assessment for a PAC.

```elixir
{:ok, assessment} = Thunderline.Agents.PACAgent.assess_context(agent_pid, context)
```

#### `make_decision/2`
Triggers decision making process.

```elixir
{:ok, decision} = Thunderline.Agents.PACAgent.make_decision(agent_pid, assessment)
```

#### `execute_action/2`
Executes a chosen action.

```elixir
{:ok, result} = Thunderline.Agents.PACAgent.execute_action(agent_pid, decision)
```

#### `form_memory/2`
Forms memory from experience.

```elixir
{:ok, memory} = Thunderline.Agents.PACAgent.form_memory(agent_pid, experience)
```

### Thunderline.MCP.ToolRegistry

MCP tool management.

#### `register_tool/1`
Registers a new tool.

```elixir
:ok = Thunderline.MCP.ToolRegistry.register_tool(%{
  name: "custom_tool",
  description: "Does something useful",
  category: "utility",
  module: MyApp.CustomTool,
  input_schema: %{
    type: "object",
    required: ["param1"],
    properties: %{
      "param1" => %{type: "string"}
    }
  }
})
```

#### `get_tool/1`
Retrieves tool specification.

```elixir
{:ok, tool_spec} = Thunderline.MCP.ToolRegistry.get_tool("tool_name")
```

#### `get_all_tools/0`
Lists all registered tools.

```elixir
{:ok, tools} = Thunderline.MCP.ToolRegistry.get_all_tools()
```

#### `get_tools_by_category/1`
Gets tools by category.

```elixir
{:ok, tools} = Thunderline.MCP.ToolRegistry.get_tools_by_category("memory")
```

### Thunderline.MCP.ToolRouter

Tool execution engine.

#### `execute_tool/3`
Executes a tool with given inputs and context.

```elixir
context = %{
  pac_id: "pac-uuid",
  zone_id: "zone-uuid", 
  tick_count: 42,
  agent_pid: self(),
  metadata: %{}
}

{:ok, result} = Thunderline.MCP.ToolRouter.execute_tool(
  "memory_search",
  %{"query" => "recent conversations"},
  context
)
```

#### `list_tools/0`
Lists available tools with schemas.

```elixir
{:ok, tool_schemas} = Thunderline.MCP.ToolRouter.list_tools()
```

### Thunderline.Memory.Manager

Memory management system.

#### `store_memory/2`
Stores a memory for a PAC.

```elixir
{:ok, memory_id} = Thunderline.Memory.Manager.store_memory(pac_id, %{
  content: "Had an interesting conversation about AI",
  type: "social",
  importance: 0.8,
  tags: ["conversation", "ai"]
})
```

#### `get_relevant_memories/3`
Retrieves relevant memories for a query.

```elixir
{:ok, memories} = Thunderline.Memory.Manager.get_relevant_memories(
  pac_id,
  "conversations about technology",
  10
)
```

#### `search_memories/3`
Semantic search across memories.

```elixir
{:ok, results} = Thunderline.Memory.Manager.search_memories(
  pac_id,
  "learning experiences",
  %{limit: 5, threshold: 0.7}
)
```

### Thunderline.Tick.Pipeline

Tick processing pipeline.

#### `execute_tick/2`
Executes a complete tick cycle for a PAC.

```elixir
{:ok, tick_result} = Thunderline.Tick.Pipeline.execute_tick(pac, tick_context)
```

**Returns:**
```elixir
%{
  assessment: %{...},
  decision: %{...},
  execution_result: %{...},
  memory: %{...},
  narrative: "Generated story context",
  updated_pac: %Thunderline.PAC{}
}
```

### Thunderline.MCP.PromptManager

AI prompt management.

#### `generate_context_prompt/1`
Generates context assessment prompt.

```elixir
prompt = Thunderline.MCP.PromptManager.generate_context_prompt(%{
  pac_name: "Alice",
  traits: ["curious", "analytical"],
  stats: %{"intelligence" => 75},
  environment_context: "Virtual workspace",
  memories: ["Recent memory 1", "Recent memory 2"],
  available_tools: ["memory_search", "communicate"]
})
```

#### `generate_decision_prompt/1`
Generates decision making prompt.

```elixir
prompt = Thunderline.MCP.PromptManager.generate_decision_prompt(%{
  pac_name: "Alice",
  assessment: assessment_result,
  goals: ["Learn new things", "Help others"],
  available_actions: ["explore", "socialize", "create"],
  traits: ["curious"],
  stats: %{"creativity" => 80}
})
```

#### `register_template/2`
Registers custom prompt template.

```elixir
:ok = Thunderline.MCP.PromptManager.register_template(:custom_template, """
You are #{pac_name} in #{situation}.
Please #{instruction}.
""")
```

## 🛠️ MCP Tools

### Built-in Tools

#### Memory Search Tool
Searches semantic memory for relevant information.

**Tool Name:** `"memory_search"`

**Input Schema:**
```json
{
  "type": "object",
  "required": ["query"],
  "properties": {
    "query": {"type": "string", "description": "Search query"},
    "limit": {"type": "integer", "description": "Max results", "default": 10}
  }
}
```

**Example Usage:**
```elixir
{:ok, result} = Thunderline.MCP.ToolRouter.execute_tool(
  "memory_search",
  %{"query" => "recent conversations", "limit" => 5},
  context
)
```

#### Communication Tool
Sends messages to other PACs or environment.

**Tool Name:** `"communicate"`

**Input Schema:**
```json
{
  "type": "object", 
  "required": ["target", "message"],
  "properties": {
    "target": {"type": "string", "description": "Target PAC ID or 'environment'"},
    "message": {"type": "string", "description": "Message content"},
    "channel": {"type": "string", "description": "Communication channel", "default": "default"}
  }
}
```

#### Observation Tool
Observes environment and context.

**Tool Name:** `"observe"`

**Input Schema:**
```json
{
  "type": "object",
  "properties": {
    "scope": {"type": "string", "description": "Observation scope", "default": "local"},
    "details": {"type": "boolean", "description": "Include detailed info", "default": false}
  }
}
```

## 🔄 Async Operations

### Oban Jobs

#### Schedule PAC Tick
```elixir
# Schedule immediate tick
%{pac_id: pac.id, tick_number: 1}
|> Thunderline.Tick.TickWorker.new()
|> Oban.insert()

# Schedule delayed tick
%{pac_id: pac.id, tick_number: 2}
|> Thunderline.Tick.TickWorker.new(schedule_in: 300) # 5 minutes
|> Oban.insert()
```

### PubSub Events

#### Subscribe to PAC Events
```elixir
Phoenix.PubSub.subscribe(Thunderline.PubSub, "pac:#{pac.id}")
```

#### PAC Event Types
- `{:pac_activated, pac}`
- `{:pac_deactivated, pac}`
- `{:tick_completed, pac_id, tick_result}`
- `{:action_executed, pac_id, action, result}`
- `{:memory_formed, pac_id, memory}`

## 🚨 Error Handling

### Common Error Patterns

#### Resource Not Found
```elixir
case Thunderline.PAC.get("invalid-id") do
  {:ok, pac} -> # Success
  {:error, :not_found} -> # Handle not found
end
```

#### Validation Errors
```elixir
case Thunderline.PAC.create(%{name: ""}) do
  {:ok, pac} -> # Success
  {:error, changeset} -> 
    errors = changeset.errors
    # Handle validation errors
end
```

#### Tool Execution Errors
```elixir
case Thunderline.MCP.ToolRouter.execute_tool(tool, inputs, context) do
  {:ok, result} -> # Success
  {:error, :tool_not_found, message} -> # Tool not available
  {:error, :invalid_input, details} -> # Input validation failed
  {:error, :execution_failed, reason} -> # Tool execution failed
end
```

### Error Recovery Strategies

#### Retry with Backoff
```elixir
Enum.reduce_while(1..3, nil, fn attempt, _acc ->
  case risky_operation() do
    {:ok, result} -> {:halt, result}
    {:error, _} when attempt < 3 -> 
      Process.sleep(attempt * 1000)
      {:cont, nil}
    {:error, reason} -> {:halt, {:error, reason}}
  end
end)
```

#### Circuit Breaker Pattern
```elixir
case Thunderline.CircuitBreaker.call(:external_service, fn ->
  external_api_call()
end) do
  {:ok, result} -> result
  {:error, :circuit_open} -> use_fallback()
  {:error, reason} -> handle_error(reason)
end
```

## 📊 Monitoring & Telemetry

### Health Checks

#### System Health
```elixir
health = Thunderline.HealthCheck.status()
# Returns: %{database: :ok, memory: :ok, oban: :ok}
```

#### PAC Health
```elixir
pac_health = Thunderline.PAC.Manager.health_check(pac)
# Returns: %{agent_status: :running, last_tick: timestamp}
```

### Metrics

#### Performance Metrics
```elixir
metrics = Thunderline.Metrics.get_performance_stats()
# Returns tick processing times, memory usage, etc.
```

#### PAC Metrics
```elixir
pac_metrics = Thunderline.Metrics.get_pac_stats(pac_id)
# Returns tick count, success rate, average response time
```

## 🔧 Configuration

### Application Configuration
```elixir
# config/config.exs
config :thunderline,
  # AI Provider
  ai_provider: :openai,
  openai_api_key: {:system, "OPENAI_API_KEY"},
  openai_base_url: "https://api.openai.com/v1",
  
  # Memory
  embedding_model: "text-embedding-3-small",
  memory_similarity_threshold: 0.7,
  
  # Ticks
  tick_interval: :timer.minutes(5),
  max_concurrent_ticks: 10
```

### Runtime Configuration
```elixir
# Update configuration at runtime
Application.put_env(:thunderline, :tick_interval, :timer.minutes(10))
```

## 🔐 Security

### Authentication
```elixir
# Verify PAC ownership
case Thunderline.Auth.verify_pac_access(user_id, pac_id) do
  {:ok, :authorized} -> # Allow access
  {:error, :forbidden} -> # Deny access
end
```

### Input Validation
```elixir
# All inputs are validated through schemas
case Thunderline.PAC.create(untrusted_input) do
  {:ok, pac} -> # Input was valid
  {:error, changeset} -> # Input validation failed
end
```

---

For more detailed examples and advanced usage patterns, see the [Development Guide](DEVELOPMENT.md).
