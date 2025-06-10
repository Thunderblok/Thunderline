defmodule Thunderline.Tick.Broadway do
  @moduledoc """
  Broadway-powered tick processing pipeline for Thunderline agents.

  This module uses Broadway to handle high-throughput, fault-tolerant
  processing of agent tick cycles. It provides:

  - Concurrent processing of multiple agents
  - Automatic retry and error handling
  - Back-pressure management
  - Rate limiting and load balancing
  - Telemetry and monitoring

  The pipeline processes messages containing agent IDs and tick contexts,
  executing the full tick cycle for each agent in parallel.
  """

  use Broadway

  require Logger
  alias Broadway.Message
  alias Thunderline.PAC.{Agent, Manager}
  alias Thunderline.Tick.{Pipeline, Log}

  def start_link(opts) do
    config = build_config(opts)

    Broadway.start_link(__MODULE__, config)
  end

  @impl Broadway
  def handle_message(_, %Message{data: %{agent_id: agent_id, context: context}} = message, _) do
    Logger.debug("Processing tick for agent #{agent_id}")

    case process_agent_tick(agent_id, context) do
      {:ok, result} ->
        # Log successful tick
        Log.log_tick_success(agent_id, result)

        # Update telemetry
        :telemetry.execute([:thunderline, :tick, :success], %{count: 1}, %{agent_id: agent_id})

        message

      {:error, reason} ->
        Logger.error("Tick failed for agent #{agent_id}: #{inspect(reason)}")

        # Log failure
        Log.log_tick_failure(agent_id, reason)

        # Update telemetry
        :telemetry.execute([:thunderline, :tick, :failure], %{count: 1}, %{
          agent_id: agent_id,
          reason: reason
        })

        # Mark message as failed for retry
        Message.failed(message, reason)
    end
  end

  @impl Broadway
  def handle_failed(messages, _context) do
    Logger.warning("#{length(messages)} tick messages failed, will retry")

    Enum.each(messages, fn %Message{data: %{agent_id: agent_id}} ->
      :telemetry.execute([:thunderline, :tick, :retry], %{count: 1}, %{agent_id: agent_id})
    end)

    messages
  end

  @impl Broadway
  def handle_batch(_, messages, _, _) do
    # Process batch completion for analytics
    agent_count = length(messages)

    Logger.debug("Completed batch of #{agent_count} agent ticks")

    :telemetry.execute([:thunderline, :tick, :batch_complete], %{count: agent_count}, %{})

    messages
  end

  # Private Functions

  defp build_config(opts) do
    [
      name: __MODULE__,
      producer: [
        module: {Thunderline.Tick.Producer, []},
        transformer: {__MODULE__, :transform, []},
        concurrency: 1
      ],
      processors: [
        default: [
          concurrency: get_concurrency(),
          min_demand: 5,
          max_demand: 10
        ]
      ],
      batchers: [
        analytics: [
          concurrency: 1,
          batch_size: 50,
          batch_timeout: 5_000
        ]
      ],
      context: %{
        tick_interval: Keyword.get(opts, :tick_interval, 30_000),
        max_retries: Keyword.get(opts, :max_retries, 3)
      }
    ]
  end

  defp get_concurrency do
    # Base concurrency on system resources
    cores = System.schedulers_online()
    max(2, div(cores, 2))
  end

  defp process_agent_tick(agent_id, context) do
    with {:ok, agent} <- Agent.get_by_id(agent_id, load: [:zone, :mods]),
         {:ok, result} <- Pipeline.execute_tick(agent, context) do

      # Update agent state with results
      state_changes = Map.get(result, :state_changes, %{})
      stat_changes = Map.get(result, :stat_changes, %{})

      # Merge changes
      updates = %{}
      |> maybe_put(:state, merge_state_changes(agent.state, state_changes))
      |> maybe_put(:stats, merge_stat_changes(agent.stats, stat_changes))

      # Apply updates if any
      case updates do
        empty when map_size(empty) == 0 ->
          {:ok, result}

        changes ->
          case Agent.update(agent, changes) do
            {:ok, _updated_agent} -> {:ok, result}
            {:error, reason} -> {:error, {:update_failed, reason}}
          end
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp merge_state_changes(current_state, changes) do
    Map.merge(current_state, changes)
  end

  defp merge_stat_changes(current_stats, changes) do
    Map.merge(current_stats, changes, fn _key, current, change ->
      case {current, change} do
        {curr, delta} when is_number(curr) and is_number(delta) ->
          max(0, min(100, curr + delta))  # Keep stats in 0-100 range

        {_curr, new_value} ->
          new_value
      end
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # Transform function for producer messages
  def transform(event, _opts) do
    %Message{
      data: event,
      acknowledger: {__MODULE__, :ack_id, :ack_data}
    }
  end

  # Simple acknowledger (messages are already processed)
  def ack(:ack_id, successful, failed) do
    Logger.debug("Acknowledged #{length(successful)} successful, #{length(failed)} failed messages")
    :ok
  end
end
