# 🎯 THUNDERLINE Examples & Use Cases

## Overview

This document provides practical examples and common use cases for the Thunderline modular substrate. Each example includes complete code samples and explanations.

## 🤖 Basic PAC Creation and Management

### Creating Your First PAC

```elixir
# Create a curious, analytical PAC
{:ok, alice} = Thunderline.PAC.create(%{
  name: "Alice",
  stats: %{
    "curiosity" => 85,
    "intelligence" => 78,
    "creativity" => 70,
    "social" => 65
  },
  traits: ["analytical", "curious", "patient"],
  state: %{
    "energy" => 100,
    "mood" => "curious",
    "current_goal" => "explore the environment"
  }
})

IO.puts("Created PAC: #{alice.name} with ID #{alice.id}")
```

### Setting Up a Zone for PACs

```elixir
# Create a virtual workspace zone
{:ok, workspace} = Thunderline.PAC.Zone.create(%{
  name: "Virtual Workspace",
  zone_type: "digital",
  description: "A collaborative digital environment",
  properties: %{
    "capacity" => 10,
    "tools_available" => ["computer", "internet", "books"],
    "atmosphere" => "focused"
  }
})

# Assign Alice to the workspace
{:ok, alice} = Thunderline.PAC.Manager.assign_to_zone(alice, workspace)
```

### Activating a PAC with AI Agent

```elixir
# Start the AI agent for Alice
{:ok, agent_pid} = Thunderline.PAC.Manager.activate_pac(alice)

# The PAC is now autonomous and can think/act independently
IO.puts("Alice's AI agent is now running with PID: #{inspect(agent_pid)}")
```

## 🧠 AI Reasoning Examples

### Manual Context Assessment

```elixir
# Prepare context for assessment
context = %{
  pac: alice,
  zone_context: %{
    zone: workspace,
    other_pacs: [],
    available_resources: ["computer", "books"]
  },
  memories: [],
  available_tools: ["memory_search", "observe", "communicate"],
  tick_count: 1
}

# Trigger context assessment
{:ok, assessment} = Thunderline.Agents.PACAgent.assess_context(agent_pid, context)

IO.inspect(assessment, label: "Alice's Assessment")
# Output: %{
#   observations: ["I'm in a quiet workspace", "No other PACs present"],
#   emotional_state: "curious and ready to explore",
#   opportunities: ["Learn about available tools", "Explore the environment"],
#   threats: [],
#   resources: ["computer", "books"],
#   priorities: ["understand my capabilities", "explore surroundings"]
# }
```

### Decision Making Process

```elixir
# Make a decision based on assessment
decision_context = %{
  assessment: assessment,
  goals: ["explore environment", "learn new things"],
  available_actions: ["observe", "use_computer", "read_books", "rest"],
  pac_config: %{
    pac_name: alice.name,
    traits: alice.traits,
    stats: alice.stats
  }
}

{:ok, decision} = Thunderline.Agents.PACAgent.make_decision(agent_pid, decision_context)

IO.inspect(decision, label: "Alice's Decision")
# Output: %{
#   chosen_action: "observe",
#   reasoning: "I should first understand my environment before taking other actions",
#   expected_outcome: "Learn about my surroundings and available options",
#   confidence: 0.85,
#   backup_plan: "If observation fails, I'll try using the computer"
# }
```

## 🛠️ MCP Tool Usage Examples

### Memory Search Tool

```elixir
# Store some memories first
{:ok, _} = Thunderline.Memory.Manager.store_memory(alice.id, %{
  content: "Alice explored the virtual workspace and found it peaceful",
  type: "exploration",
  importance: 0.7,
  tags: ["workspace", "exploration", "environment"]
})

{:ok, _} = Thunderline.Memory.Manager.store_memory(alice.id, %{
  content: "Alice learned about available tools: computer, books, internet",
  type: "learning", 
  importance: 0.8,
  tags: ["tools", "learning", "capabilities"]
})

# Now search memories using the tool
execution_context = %{
  pac_id: alice.id,
  zone_id: workspace.id,
  tick_count: 2,
  agent_pid: agent_pid,
  metadata: %{action_type: "memory_search"}
}

{:ok, search_result} = Thunderline.MCP.ToolRouter.execute_tool(
  "memory_search",
  %{"query" => "workspace exploration", "limit" => 5},
  execution_context
)

IO.inspect(search_result, label: "Memory Search Results")
```

### Communication Tool

```elixir
# Create another PAC for communication
{:ok, bob} = Thunderline.PAC.create(%{
  name: "Bob",
  traits: ["friendly", "helpful"],
  stats: %{"social" => 80}
})

{:ok, bob} = Thunderline.PAC.Manager.assign_to_zone(bob, workspace)
{:ok, bob_agent} = Thunderline.PAC.Manager.activate_pac(bob)

# Alice sends a message to Bob
{:ok, comm_result} = Thunderline.MCP.ToolRouter.execute_tool(
  "communicate",
  %{
    "target" => bob.id,
    "message" => "Hello Bob! I'm new to this workspace. Could you show me around?",
    "channel" => "direct"
  },
  execution_context
)

IO.inspect(comm_result, label: "Communication Result")
```

### Environment Observation Tool

```elixir
# Observe the current environment
{:ok, observation} = Thunderline.MCP.ToolRouter.execute_tool(
  "observe",
  %{"scope" => "zone", "details" => true},
  execution_context
)

IO.inspect(observation, label: "Environment Observation")
# Output: %{
#   zone_info: %{name: "Virtual Workspace", type: "digital"},
#   other_entities: [%{name: "Bob", type: "pac", status: "active"}],
#   available_resources: ["computer", "books", "internet"],
#   environmental_factors: %{atmosphere: "focused", noise_level: "quiet"}
# }
```

## 🔄 Complete Tick Cycle Example

### Automated PAC Evolution

```elixir
# Schedule a tick for Alice (this normally happens automatically)
tick_job = %{pac_id: alice.id, tick_number: 1}
{:ok, job} = Thunderline.Tick.TickWorker.new(tick_job) |> Oban.insert()

# Or manually execute a tick cycle
{:ok, tick_result} = Thunderline.Tick.Pipeline.execute_tick(alice, %{
  zone_context: %{zone: workspace, other_pacs: [bob]},
  available_tools: ["memory_search", "communicate", "observe"],
  tick_count: 1
})

IO.inspect(tick_result, label: "Complete Tick Result")
# Output includes:
# - assessment: Alice's situation analysis
# - decision: What Alice chose to do
# - execution_result: Results of Alice's action
# - memory: New memory formed from the experience
# - narrative: Story description of what happened
```

## 🎨 Custom Tool Development

### Creating a Custom Tool

```elixir
defmodule MyApp.Tools.WebSearch do
  @behaviour Thunderline.MCP.Tool
  
  def execute(inputs, context) do
    query = Map.get(inputs, "query")
    max_results = Map.get(inputs, "max_results", 5)
    
    # Simulate web search (replace with actual implementation)
    results = [
      %{title: "Elixir Documentation", url: "https://elixir-lang.org", snippet: "..."},
      %{title: "BEAM Ecosystem", url: "https://beam.community", snippet: "..."}
    ]
    |> Enum.take(max_results)
    
    {:ok, %{
      query: query,
      results: results,
      count: length(results)
    }}
  end
end

# Register the custom tool
:ok = Thunderline.MCP.ToolRegistry.register_tool(%{
  name: "web_search",
  description: "Search the web for information",
  category: "research",
  module: MyApp.Tools.WebSearch,
  input_schema: %{
    type: "object",
    required: ["query"],
    properties: %{
      "query" => %{type: "string", description: "Search query"},
      "max_results" => %{type: "integer", description: "Maximum results", default: 5}
    }
  }
})

# Use the custom tool
{:ok, search_results} = Thunderline.MCP.ToolRouter.execute_tool(
  "web_search",
  %{"query" => "Elixir programming", "max_results" => 3},
  execution_context
)
```

### Custom Action Development

```elixir
defmodule MyApp.Actions.LearnSkill do
  use Jido.Action,
    name: "learn_skill",
    description: "Learn a new skill based on available resources",
    schema: [
      skill_name: [type: :string, required: true],
      pac_config: [type: :map, required: true],
      available_resources: [type: {:list, :string}, default: []]
    ]
  
  @impl true
  def run(params, context) do
    %{skill_name: skill, pac_config: pac_config, available_resources: resources} = params
    
    # Determine learning approach based on PAC traits
    approach = determine_learning_approach(pac_config.traits, resources)
    
    # Calculate learning progress based on stats
    intelligence = Map.get(pac_config.stats, "intelligence", 50)
    curiosity = Map.get(pac_config.stats, "curiosity", 50)
    progress = calculate_progress(intelligence, curiosity)
    
    # Create learning result
    result = %{
      skill: skill,
      approach: approach,
      progress: progress,
      energy_cost: 15,
      new_trait: maybe_gain_trait(skill, progress)
    }
    
    {:ok, result}
  end
  
  defp determine_learning_approach(traits, resources) do
    cond do
      "analytical" in traits and "computer" in resources -> "research_and_practice"
      "social" in traits -> "collaborative_learning"
      "creative" in traits -> "experimental_approach"
      true -> "structured_study"
    end
  end
  
  defp calculate_progress(intelligence, curiosity) do
    base_progress = (intelligence + curiosity) / 200
    variation = :rand.uniform() * 0.3 - 0.15  # ±15% variation
    max(0.1, min(1.0, base_progress + variation))
  end
  
  defp maybe_gain_trait(skill, progress) when progress > 0.8 do
    case skill do
      "programming" -> "technical"
      "art" -> "artistic"
      "music" -> "musical"
      _ -> nil
    end
  end
  defp maybe_gain_trait(_, _), do: nil
end

# Add to PAC agent actions
defmodule MyApp.PAC.LearningAgent do
  use Jido.Agent,
    actions: [
      Thunderline.Agents.Actions.AssessContext,
      Thunderline.Agents.Actions.MakeDecision,
      Thunderline.Agents.Actions.ExecuteAction,
      Thunderline.Agents.Actions.FormMemory,
      MyApp.Actions.LearnSkill  # Add custom action
    ]
end
```

## 🌐 Multi-PAC Interactions

### Social Scenarios

```elixir
# Create a small community of PACs
pacs = [
  %{name: "Alice", traits: ["analytical", "curious"], role: "researcher"},
  %{name: "Bob", traits: ["creative", "artistic"], role: "designer"}, 
  %{name: "Carol", traits: ["social", "helpful"], role: "facilitator"}
]

# Create PACs and assign to shared zone
{:ok, community_zone} = Thunderline.PAC.Zone.create(%{
  name: "Community Hub",
  zone_type: "social",
  description: "A space for collaboration and interaction"
})

created_pacs = Enum.map(pacs, fn pac_data ->
  {:ok, pac} = Thunderline.PAC.create(pac_data)
  {:ok, pac} = Thunderline.PAC.Manager.assign_to_zone(pac, community_zone)
  {:ok, agent_pid} = Thunderline.PAC.Manager.activate_pac(pac)
  {pac, agent_pid}
end)

# Set up communication chain
[{alice, alice_agent}, {bob, bob_agent}, {carol, carol_agent}] = created_pacs

# Alice starts a conversation
{:ok, _} = Thunderline.MCP.ToolRouter.execute_tool(
  "communicate",
  %{
    "target" => "environment",
    "message" => "Hello everyone! I'm working on a research project about AI collaboration. Anyone interested in contributing?",
    "channel" => "general"
  },
  %{pac_id: alice.id, zone_id: community_zone.id, agent_pid: alice_agent, metadata: %{}}
)
```

### Collaborative Problem Solving

```elixir
# Define a shared problem for the PAC community
problem = %{
  title: "Design an Eco-Friendly Transportation System",
  description: "Create a sustainable transportation solution for urban areas",
  constraints: ["budget: $1M", "timeline: 6 months", "environmental impact: minimal"],
  required_skills: ["research", "design", "planning", "analysis"]
}

# Store problem as shared memory in the zone
{:ok, problem_memory} = Thunderline.Memory.Manager.store_zone_memory(community_zone.id, %{
  content: "Community Problem: #{problem.title} - #{problem.description}",
  type: "shared_goal",
  importance: 1.0,
  tags: ["collaboration", "problem_solving", "transportation", "environment"]
})

# Each PAC can now discover and contribute to the problem through their tick cycles
# Alice might research existing solutions
# Bob might design visual concepts  
# Carol might coordinate team communication
```

## 🎭 Narrative Generation

### Story Context Example

```elixir
# Generate narrative for a tick cycle
narrative_context = %{
  pac_name: "Alice",
  zone_name: "Virtual Workspace", 
  action_taken: "observe",
  action_result: %{
    discovered: ["computer workstation", "digital library", "collaboration tools"],
    mood_change: "curious to focused"
  },
  other_entities: ["Bob (working at computer)", "helpful AI assistant"],
  environmental_details: %{
    time_of_day: "afternoon",
    atmosphere: "quiet concentration",
    lighting: "soft blue glow from screens"
  }
}

narrative = Thunderline.Narrative.Engine.generate_story_segment(narrative_context)

IO.puts(narrative)
# Output: "Alice surveyed the virtual workspace with growing interest. The afternoon 
# light cast a soft blue glow across the room, where Bob was quietly focused on his 
# computer work. She noticed the well-equipped workstation and extensive digital 
# library, feeling her curiosity transform into determined focus..."
```

## 📊 Monitoring and Analytics

### PAC Performance Tracking

```elixir
# Monitor Alice's activity over time
alice_stats = Thunderline.Analytics.get_pac_performance(alice.id, %{
  timeframe: :last_week,
  metrics: [:tick_count, :action_success_rate, :learning_progress, :social_interactions]
})

IO.inspect(alice_stats)
# Output: %{
#   tick_count: 1680,  # One tick every 6 minutes
#   action_success_rate: 0.87,
#   learning_progress: %{
#     skills_acquired: ["programming", "research"],
#     traits_developed: ["technical", "methodical"]
#   },
#   social_interactions: %{
#     messages_sent: 45,
#     conversations_initiated: 12,
#     collaborative_projects: 3
#   }
# }
```

### System Health Monitoring

```elixir
# Check overall system health
health_report = Thunderline.Monitoring.system_health()

IO.inspect(health_report)
# Output: %{
#   active_pacs: 25,
#   tick_processing: %{
#     average_duration: "85ms",
#     success_rate: 0.96,
#     queue_depth: 3
#   },
#   memory_usage: %{
#     total_memories: 15420,
#     average_retrieval_time: "12ms",
#     storage_efficiency: 0.94
#   },
#   tool_usage: %{
#     most_used: ["memory_search", "communicate", "observe"],
#     error_rate: 0.02
#   }
# }
```

## 🔧 Advanced Configuration

### Custom AI Provider

```elixir
defmodule MyApp.CustomAIProvider do
  @behaviour Thunderline.AI.Provider
  
  def generate_response(prompt, opts \\ []) do
    # Custom AI implementation
    # Could integrate with local models, different APIs, etc.
    
    response = call_custom_ai_service(prompt, opts)
    
    case response do
      {:ok, text} -> {:ok, parse_ai_response(text)}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp call_custom_ai_service(prompt, opts) do
    # Implementation details...
    {:ok, "AI generated response"}
  end
  
  defp parse_ai_response(text) do
    # Parse structured response from AI
    Jason.decode(text)
  end
end

# Configure custom provider
config :thunderline,
  ai_provider: MyApp.CustomAIProvider,
  custom_ai_options: %{
    model: "custom-model-v1",
    temperature: 0.7
  }
```

### Dynamic Tool Loading

```elixir
# Load tools from external modules at runtime
defmodule MyApp.ToolLoader do
  def load_plugin_tools(plugin_dir) do
    plugin_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".beam"))
    |> Enum.each(fn file ->
      module_name = String.replace(file, ".beam", "") |> String.to_atom()
      
      if function_exported?(module_name, :tool_spec, 0) do
        tool_spec = apply(module_name, :tool_spec, [])
        Thunderline.MCP.ToolRegistry.register_tool(tool_spec)
      end
    end)
  end
end

# Load tools from plugins directory
MyApp.ToolLoader.load_plugin_tools("./priv/plugins/")
```

---

These examples demonstrate the flexibility and power of the Thunderline substrate. Each example can be extended and customized based on specific use cases and requirements.
