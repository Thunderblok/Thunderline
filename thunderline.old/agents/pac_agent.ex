defmodule Thunderline.Agents.PACAgent do
  @moduledoc """
  Jido AI Agent wrapper for Personal Autonomous Creations (PACs).

  This module implements the core AI reasoning layer for PACs, integrating:
  - Jido Agent framework for autonomous behavior
  - Memory retrieval for context-aware decisions
  - MCP tool integration for environment interaction
  - Prompt templates for consistent AI behavior

  Each PAC gets its own agent instance with personalized configuration
  based on its traits, stats, and current state.
  """

  use Jido.Agent,
    name: "thunderline_pac_agent",
    description: "AI reasoning agent for Personal Autonomous Creations",
    category: "PAC Agents",
    tags: ["AI", "PAC", "Reasoning", "Evolution"],
    vsn: "1.0.0",
    actions: [
      Thunderline.Agents.Actions.AssessContext,
      Thunderline.Agents.Actions.MakeDecision,
      Thunderline.Agents.Actions.ExecuteAction,
      Thunderline.Agents.Actions.FormMemory
    ]

  require Logger

  alias Thunderline.{PAC, MCP, Memory}
  alias Thunderline.MCP.{PromptManager, ToolRegistry}
  alias Thunderline.Memory.Manager, as: MemoryManager

  @type agent_result :: {:ok, term()} | {:error, term()}
  @type reasoning_context :: %{
    pac: PAC.t(),
    zone_context: map(),
    memories: list(),
    available_tools: list(),
    tick_count: integer()
  }

  # Agent Configuration

  @impl true
  def mount(agent, opts) do
    Logger.debug("Mounting PAC agent with opts: #{inspect(opts)}")

    pac_config = Keyword.get(opts, :pac_config, %{})

    updated_state =
      agent.state
      |> Map.put(:pac_config, pac_config)
      |> Map.put(:reasoning_history, [])
      |> Map.put(:tool_registry, nil)
      |> Map.put(:prompt_templates, %{})

    {:ok, %{agent | state: updated_state}}
  end

  # Core Reasoning Functions

  @doc """
  Assess the current context and situation for a PAC.

  Retrieves relevant memories, evaluates environmental factors,
  and builds a comprehensive understanding of the current state.
  """
  @spec assess_context(pid(), reasoning_context()) :: agent_result()
  def assess_context(agent_pid, context) do
    signal = build_signal("thunderline.pac.assess_context", context)
    call(agent_pid, signal)
  end

  @doc """
  Make a decision based on assessed context.

  Uses AI reasoning to determine the best course of action
  given the PAC's goals, constraints, and available options.
  """
  @spec make_decision(pid(), map()) :: agent_result()
  def make_decision(agent_pid, assessment) do
    signal = build_signal("thunderline.pac.make_decision", assessment)
    call(agent_pid, signal)
  end

  @doc """
  Execute a chosen action using available MCP tools.

  Translates high-level decisions into concrete actions
  via the MCP tool registry.
  """
  @spec execute_action(pid(), map()) :: agent_result()
  def execute_action(agent_pid, decision) do
    signal = build_signal("thunderline.pac.execute_action", decision)
    call(agent_pid, signal)
  end

  @doc """
  Form new memories from tick experiences.

  Processes the results of actions and decisions to create
  meaningful memories for future context retrieval.
  """
  @spec form_memory(pid(), map()) :: agent_result()
  def form_memory(agent_pid, experience) do
    signal = build_signal("thunderline.pac.form_memory", experience)
    call(agent_pid, signal)
  end

  # Agent Lifecycle

  @doc """
  Start a PAC agent with specific configuration.

  Creates a Jido agent instance tailored to the PAC's
  personality, capabilities, and current state.
  """
  @spec start_pac_agent(PAC.t(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start_pac_agent(%PAC{} = pac, opts \\ []) do
    agent_config = build_agent_config(pac)

    start_opts = [
      id: "pac_#{pac.id}",
      pac_config: agent_config,
      registry: Thunderline.AgentRegistry
    ] ++ opts

    case start_link(start_opts) do
      {:ok, pid} ->
        Logger.info("Started PAC agent for #{pac.name} (#{pac.id})")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start PAC agent for #{pac.name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stop a PAC agent gracefully.
  """
  @spec stop_pac_agent(PAC.t()) :: :ok
  def stop_pac_agent(%PAC{} = pac) do
    agent_id = "pac_#{pac.id}"

    case Jido.resolve_pid(agent_id) do
      {:ok, pid} ->
        GenServer.stop(pid, :normal)
        Logger.info("Stopped PAC agent for #{pac.name} (#{pac.id})")

      {:error, _} ->
        Logger.debug("PAC agent for #{pac.name} was not running")
    end

    :ok
  end

  # Configuration Helpers

  defp build_agent_config(%PAC{} = pac) do
    %{
      pac_id: pac.id,
      pac_name: pac.name,
      stats: pac.stats,
      traits: pac.traits,
      agent_config: pac.agent_config,
      personality: extract_personality(pac),
      capabilities: extract_capabilities(pac),
      goals: extract_goals(pac)
    }
  end

  defp extract_personality(%PAC{traits: traits, stats: stats}) do
    %{
      traits: traits,
      dominant_stats: find_dominant_stats(stats),
      communication_style: infer_communication_style(traits, stats),
      decision_tendency: infer_decision_tendency(stats)
    }
  end

  defp extract_capabilities(%PAC{mods: mods} = pac) when is_list(mods) do
    mods
    |> Enum.filter(& &1.active)
    |> Enum.group_by(& &1.category)
    |> Map.new(fn {category, mods} ->
      {category, Enum.map(mods, & &1.name)}
    end)
  end
  defp extract_capabilities(_), do: %{}

  defp extract_goals(%PAC{state: %{"goals" => goals}}) when is_list(goals), do: goals
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
