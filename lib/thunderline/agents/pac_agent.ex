# ☤ PAC Agent - Jido AI Agent System
defmodule Thunderline.Agents.PACAgent do
  @moduledoc """
  Jido AI Agent wrapper for Personal Autonomous Creations (PAC Agents). ☤

  This module implements the core AI reasoning layer for PAC Agents, integrating:
  - Jido Agent framework for autonomous behavior
  - Memory retrieval for context-aware decisions
  - MCP tool integration for environment interaction
  - Prompt templates for consistent AI behavior
  - Federation-aware reasoning across supervisor nodes

  Each PAC Agent gets its own agent instance with personalized configuration
  based on its traits, stats, and current state.
  """

  use Jido.Agent,
    name: "thunderline_pac_agent",
    description: "AI reasoning agent for Personal Autonomous Creations",
    category: "PAC Agents",
    tags: ["AI", "PAC", "Reasoning", "Evolution", "Federation"],
    vsn: "2.0.0",
    actions: [
      Thunderline.Agents.Actions.AssessContext,
      Thunderline.Agents.Actions.MakeDecision,
      Thunderline.Agents.Actions.ExecuteAction,
      Thunderline.Agents.Actions.FormMemory
    ]

  require Logger
  alias Thunderline.PAC.{Agent, Zone, Manager}
  alias Thunderline.MCP.{Server, ToolRegistry}
  alias Thunderline.Memory.Manager, as: MemoryManager
  alias Thunderline.Agents.AIProvider

  @type agent_result :: {:ok, term()} | {:error, term()}
  @type reasoning_context :: %{
    agent: Agent.t(),
    zone_context: map(),
    memories: list(),
    available_tools: list(),
    tick_count: integer(),
    federation_context: map()
  }

  # Agent Configuration

  @impl true
  def mount(agent, opts) do
    Logger.debug("Mounting PAC agent with opts: #{inspect(opts)}")

    agent_config = Keyword.get(opts, :agent_config, %{})
    federation_config = Keyword.get(opts, :federation_config, %{})

    updated_state =
      agent.state
      |> Map.put(:agent_config, agent_config)
      |> Map.put(:federation_config, federation_config)
      |> Map.put(:reasoning_history, [])
      |> Map.put(:tool_registry, nil)
      |> Map.put(:prompt_templates, %{})

    {:ok, %{agent | state: updated_state}}
  end

  # Core Reasoning Functions

  @doc """
  Assess the current context and situation for a PAC Agent.

  Retrieves relevant memories, evaluates environmental factors,
  and builds a comprehensive understanding of the current state
  with federation awareness.
  """
  @spec assess_context(pid(), reasoning_context()) :: agent_result()
  def assess_context(agent_pid, context) do
    signal = build_signal("thunderline.pac.assess_context", context)
    call(agent_pid, signal)
  end

  @doc """
  Make a decision based on assessed context.

  Uses AI reasoning to determine the best course of action
  given the PAC Agent's goals, constraints, available options,
  and federation context.
  """
  @spec make_decision(pid(), map()) :: agent_result()
  def make_decision(agent_pid, assessment) do
    signal = build_signal("thunderline.pac.make_decision", assessment)
    call(agent_pid, signal)
  end

  @doc """
  Execute a chosen action using available MCP tools.

  Translates high-level decisions into concrete actions
  via the MCP tool registry, with federation coordination.
  """
  @spec execute_action(pid(), map()) :: agent_result()
  def execute_action(agent_pid, decision) do
    signal = build_signal("thunderline.pac.execute_action", decision)
    call(agent_pid, signal)
  end

  @doc """
  Form new memories from tick experiences.

  Processes the results of actions and decisions to create
  meaningful memories for future context retrieval with
  federation metadata.
  """
  @spec form_memory(pid(), map()) :: agent_result()
  def form_memory(agent_pid, experience) do
    signal = build_signal("thunderline.pac.form_memory", experience)
    call(agent_pid, signal)
  end

  # High-level reasoning interface for the tick pipeline
  @doc """
  Primary reasoning entry point for PAC Agent tick cycles.

  This integrates all reasoning steps: context assessment,
  decision making, action execution, and memory formation.
  """
  @spec reason(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def reason(agent_id, prompt_context) do
    case get_or_start_agent(agent_id) do
      {:ok, agent_pid} ->
        execute_reasoning_cycle(agent_pid, prompt_context)
      {:error, reason} ->
        Logger.error("Failed to get PAC agent for #{agent_id}: #{inspect(reason)}")
        {:error, {:agent_unavailable, reason}}
    end
  end

  # Agent Lifecycle

  @doc """
  Start a PAC agent with specific configuration.

  Creates a Jido agent instance tailored to the PAC Agent's
  personality, capabilities, and current state.
  """
  @spec start_pac_agent(Agent.t(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start_pac_agent(%Agent{} = agent, opts \\ []) do
    agent_config = build_agent_config(agent)
    federation_config = build_federation_config()

    start_opts = [
      id: "pac_agent_#{agent.id}",
      agent_config: agent_config,
      federation_config: federation_config,
      registry: Thunderline.AgentRegistry
    ] ++ opts

    case start_link(start_opts) do
      {:ok, pid} ->
        Logger.info("Started PAC agent for #{agent.name} (#{agent.id})")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start PAC agent for #{agent.name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stop a PAC agent gracefully.
  """
  @spec stop_pac_agent(Agent.t()) :: :ok
  def stop_pac_agent(%Agent{} = agent) do
    agent_id = "pac_agent_#{agent.id}"

    case Registry.lookup(Thunderline.AgentRegistry, agent_id) do
      [{pid, _}] ->
        GenServer.stop(pid, :normal)
        Logger.info("Stopped PAC agent for #{agent.name} (#{agent.id})")
      [] ->
        Logger.debug("PAC agent for #{agent.name} was not running")
    end

    :ok
  end

  # Private Implementation

  defp get_or_start_agent(agent_id) do
    agent_registry_id = "pac_agent_#{agent_id}"

    case Registry.lookup(Thunderline.AgentRegistry, agent_registry_id) do
      [{pid, _}] ->
        {:ok, pid}
      [] ->
        # Agent not running, try to start it
        case Ash.get(Agent, agent_id, domain: Thunderline.Domain) do
          {:ok, agent} -> start_pac_agent(agent)
          {:error, reason} -> {:error, {:agent_not_found, reason}}
        end
    end
  end

  defp execute_reasoning_cycle(agent_pid, context) do
    with {:ok, assessment} <- assess_context(agent_pid, context),
         {:ok, decision} <- make_decision(agent_pid, Map.put(context, :assessment, assessment)),
         {:ok, action_result} <- execute_action(agent_pid, Map.put(decision, :context, context)),
         {:ok, memory} <- form_memory(agent_pid, %{
           decision: decision,
           action_result: action_result,
           context: context
         }) do

      # Return structured decision result
      {:ok, %{
        "actions" => extract_actions_from_decision(decision),
        "reasoning" => Map.get(decision, "reasoning", ""),
        "confidence" => Map.get(decision, "confidence", 0.5),
        "assessment" => assessment,
        "memory_formed" => memory
      }}
    else
      {:error, reason} ->
        Logger.warning("Reasoning cycle failed: #{inspect(reason)}")
        # Return fallback decision
        {:ok, create_fallback_decision(context)}
    end
  end

  defp extract_actions_from_decision(decision) do
    case Map.get(decision, "chosen_action") do
      action when is_binary(action) -> [action]
      actions when is_list(actions) -> actions
      _ -> ["think"] # Default fallback
    end
  end

  defp create_fallback_decision(context) do
    agent = Map.get(context, :agent)
    energy = get_in(agent.stats, ["energy"]) || 50

    action = if energy < 30, do: "rest", else: "think"

    %{
      "actions" => [action],
      "reasoning" => "Fallback decision due to reasoning failure",
      "confidence" => 0.3
    }
  end

  # Configuration Helpers

  defp build_agent_config(%Agent{} = agent) do
    %{
      agent_id: agent.id,
      agent_name: agent.name,
      stats: agent.stats,
      traits: agent.traits,
      agent_config: agent.agent_config,
      personality: extract_personality(agent),
      capabilities: extract_capabilities(agent),
      goals: extract_goals(agent)
    }
  end

  defp build_federation_config do
    %{
      node_id: Application.get_env(:thunderline, :node_id, "default_node"),
      node_capabilities: Application.get_env(:thunderline, :node_capabilities, []),
      federation_enabled: Application.get_env(:thunderline, :federation_enabled, false)
    }
  end

  defp extract_personality(%Agent{traits: traits, stats: stats}) do
    %{
      traits: traits,
      dominant_stats: find_dominant_stats(stats),
      communication_style: infer_communication_style(traits, stats),
      decision_tendency: infer_decision_tendency(stats)
    }
  end

  defp extract_capabilities(%Agent{mods: mods} = _agent) when is_list(mods) do
    mods
    |> Enum.filter(& &1.active)
    |> Enum.group_by(& &1.category)
    |> Map.new(fn {category, mods} ->
      {category, Enum.map(mods, & &1.name)}
    end)
  end
  defp extract_capabilities(_), do: %{}

  defp extract_goals(%Agent{state: %{"goals" => goals}}) when is_list(goals), do: goals
  defp extract_goals(_), do: []

  defp find_dominant_stats(stats) do
    stats
    |> Enum.sort_by(fn {_k, v} -> v end, :desc)
    |> Enum.take(2)
    |> Enum.map(fn {k, _v} -> k end)
  end

  defp infer_communication_style(traits, stats) do
    cond do
      "social" in traits or stats["social"] > 70 -> "collaborative"
      "analytical" in traits or stats["intelligence"] > 70 -> "logical"
      "creative" in traits or stats["creativity"] > 70 -> "expressive"
      true -> "balanced"
    end
  end

  defp infer_decision_tendency(stats) do
    cond do
      stats["curiosity"] > 70 -> "exploratory"
      stats["intelligence"] > 70 -> "analytical"
      stats["creativity"] > 70 -> "innovative"
      true -> "pragmatic"
    end
  end

  # Signal Building

  defp build_signal(signal_type, data) do
    {:ok, signal} = Jido.Signal.new(%{
      type: signal_type,
      data: data,
      timestamp: DateTime.utc_now()
    })

    signal
  end
end
