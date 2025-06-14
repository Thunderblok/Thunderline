defmodule Thunderline.Tick.TickWorker do
  @moduledoc """
  Oban Worker for executing PAC Agent tick cycles.

  This worker implements the core "heartbeat" of Thunderline - the periodic
  execution of PAC Agent reasoning and evolution. Each tick represents a moment
  where a PAC Agent:

  1. Evaluates its current state and environment
  2. Retrieves relevant memories and context
  3. Uses AI reasoning (via Jido agents) to make decisions
  4. Updates its state and performs actions
  5. Logs the tick for continuity and debugging
  6. Schedules the next tick cycle

  Ticks are fault-tolerant and resumable thanks to Oban's reliability.
  """

  use Oban.Worker,
    queue: :tick,
    max_attempts: 3,
    unique: [period: 60, fields: [:worker, :args]]

  require Logger

  alias Thunderline.PAC.{Agent, Zone}
  alias Thunderline.Memory.Manager, as: MemoryManager
  alias Thunderline.PAC.AgentTickReactor

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"agent_id" => agent_id}} = job) do
    Logger.debug("Starting tick for PAC Agent #{agent_id} using Ash AI + Reactor pipeline")

    # Extract Broadway metadata if available
    broadway_metadata = extract_broadway_metadata(job)

    with {:ok, agent} <- load_agent(agent_id),
         {:ok, result} <- AgentTickReactor.run(%{agent: agent}),
         {:ok, _log} <- create_enhanced_tick_log(agent, result, broadway_metadata) do

      # Notify orchestrator of completion
      notify_tick_completion(agent_id, result)

      Logger.debug("Completed Reactor tick for PAC Agent #{agent.name} (#{agent_id})")
      :ok
    else
      {:error, :agent_not_found} ->
        Logger.warning("PAC Agent #{agent_id} not found, skipping tick")
        :ok

      {:error, :agent_inactive} ->
        Logger.info("PAC Agent #{agent_id} is inactive, stopping ticks")
        :ok

      {:error, reason} ->
        Logger.error("Reactor tick failed for PAC Agent #{agent_id}: #{inspect(reason)}")
        notify_tick_failure(agent_id, reason)
        {:error, reason}
    end
  end

  # Private functions

  defp load_agent(agent_id) do
    case Agent.get_by_id(agent_id, load: [:zone, :mods]) do
      {:ok, agent} ->
        # Check if agent is active based on state
        case agent.state do
          %{"activity" => "inactive"} -> {:error, :agent_inactive}
          _ -> {:ok, agent}
        end

      {:error, %Ash.Error.Query.NotFound{}} ->
        {:error, :agent_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end
  # Enhanced tick logging for Reactor-based results

  defp extract_broadway_metadata(job) do
    %{
      job_id: job.id,
      queue: job.queue,
      worker: job.worker,
      attempt: job.attempt,
      max_attempts: job.max_attempts,
      scheduled_at: job.scheduled_at,
      attempted_at: job.attempted_at,
      inserted_at: job.inserted_at
    }
  end
  defp create_enhanced_tick_log(agent, reactor_result, broadway_metadata) do
    # Extract information from Reactor result structure
    action_result = Map.get(reactor_result, :action_result, %{})
    memory_data = Map.get(reactor_result, :memory_formed, %{})
    agent_updates = Map.get(reactor_result, :agent, agent)

    # Create log entry with enhanced AI-specific data
    log_attrs = %{
      agent_id: agent.id,
      node_id: get_node_id(),
      tick_number: get_next_tick_number(agent),
      decision: %{
        action: Map.get(action_result, :result_message, "unknown_action"),
        reasoning: Map.get(memory_data, :memory_content, "No reasoning recorded"),
        confidence: Map.get(memory_data, :importance_score, 0.5)
      },
      actions_taken: [action_result],
      state_changes: calculate_state_changes(agent, agent_updates),
      memories_formed: 1,
      narrative: Map.get(memory_data, :memory_content, "Agent completed tick cycle"),
      ai_response_time_ms: 0,  # TODO: Add timing
      broadway_metadata: broadway_metadata,
      errors: []
    }

    Thunderline.Tick.Log.create_tick_log(log_attrs)
  end

  defp get_node_id, do: Node.self() |> Atom.to_string()

  defp get_next_tick_number(agent) do
    # Get the last tick number from logs and increment
    case Thunderline.Tick.Log.get_for_agent_recent(agent.id, limit: 1) do
      {:ok, [last_log | _]} -> (last_log.tick_number || 0) + 1
      _ -> 1
    end
  end
  defp calculate_state_changes(old_agent, new_agent) do
    old_stats = old_agent.stats || %{}
    new_stats = Map.get(new_agent, :stats, old_stats)

    %{
      stats: %{
        energy_change: Map.get(new_stats, "energy", 0) - Map.get(old_stats, "energy", 0)
      }
    }
  end

  defp notify_tick_completion(agent_id, result) do
    # Send completion notification to orchestrator
    GenServer.cast(Thunderline.Tick.Orchestrator, {:tick_completed, agent_id, result})
  end

  defp notify_tick_failure(agent_id, reason) do
    # Send failure notification to orchestrator
    GenServer.cast(Thunderline.Tick.Orchestrator, {:tick_failed, agent_id, reason})
  end
end
