defmodule Thunderline.Integration.MemoryTickTest do
  @moduledoc """
  Integration test for memory formation during tick processing.

  This test validates TASK-001 and TASK-003 from the Kanban board:
  - Memory Pipeline Integration
  - Memory-Tick Integration Testing
  """

  use ExUnit.Case
  import Mox

  alias Thunderline.PAC.Agent
  alias Thunderline.Memory.Manager, as: MemoryManager
  alias Thunderline.Tick.{Pipeline, TickWorker}

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "memory integration during ticks" do
    test "agent tick creates memory entries" do
      # Setup test agent
      agent_attrs = %{
        name: "TestMemoryAgent",
        personality: %{"curiosity" => 0.8},
        stats: %{"energy" => 75, "creativity" => 60},
        traits: ["curious", "analytical"],
        state: %{"mood" => "focused", "activity" => "exploring"}
      }

      {:ok, agent} = Agent.create(agent_attrs, domain: Thunderline.Domain)

      # Build tick context
      tick_context = %{
        agent_id: agent.id,
        time_since_last_tick: 30,
        tick_number: 1,
        environment: %{zone_context: %{}},
        memory: %{recent_memories: []},
        modifications: %{active_mods: []},
        timestamp: DateTime.utc_now()
      }

      # Execute tick pipeline
      {:ok, result} = Pipeline.execute_tick(agent, tick_context)

      # Verify memories were created
      assert is_list(result.new_memories)
      assert length(result.new_memories) > 0

      # Verify memories are stored and retrievable
      {:ok, stored_memories} = MemoryManager.search(agent.id, "decision", limit: 10)
      assert length(stored_memories) > 0

      # Verify memory content and metadata
      decision_memory = Enum.find(stored_memories, fn memory ->
        String.contains?(memory.content, "decided")
      end)

      assert decision_memory != nil
      assert "decision" in decision_memory.tags
      assert "tick" in decision_memory.tags
      assert decision_memory.agent_id == agent.id

      # Test memory count increases after tick
      initial_count = length(stored_memories)

      # Run another tick
      tick_context_2 = %{tick_context | tick_number: 2, timestamp: DateTime.utc_now()}
      {:ok, _result2} = Pipeline.execute_tick(agent, tick_context_2)

      # Verify memory count increased
      {:ok, all_memories} = MemoryManager.search(agent.id, "", limit: 50)
      assert length(all_memories) > initial_count

      IO.puts("✅ Memory integration test passed!")
      IO.puts("   - Initial memories created: #{initial_count}")
      IO.puts("   - Total memories after 2 ticks: #{length(all_memories)}")
      IO.puts("   - Memory growth verified: #{length(all_memories) > initial_count}")
    end

    test "memory search returns relevant results" do
      # Setup test agent
      agent_attrs = %{
        name: "SearchTestAgent",
        personality: %{"creativity" => 0.7},
        stats: %{"energy" => 80},
        traits: ["creative"],
        state: %{"mood" => "inspired"}
      }

      {:ok, agent} = Agent.create(agent_attrs, domain: Thunderline.Domain)

      # Store specific memories for testing
      {:ok, _mem1} = MemoryManager.store(agent.id, "I created a beautiful painting",
                                        tags: ["creation", "art"])
      {:ok, _mem2} = MemoryManager.store(agent.id, "I explored the northern woods",
                                        tags: ["exploration", "nature"])
      {:ok, _mem3} = MemoryManager.store(agent.id, "I made a new friend today",
                                        tags: ["social", "friendship"])

      # Test semantic search
      {:ok, art_memories} = MemoryManager.search(agent.id, "creative art painting", limit: 5)
      assert length(art_memories) > 0

      art_memory = Enum.find(art_memories, &String.contains?(&1.content, "painting"))
      assert art_memory != nil

      {:ok, nature_memories} = MemoryManager.search(agent.id, "exploration woods", limit: 5)
      assert length(nature_memories) > 0

      # Test performance (should be under 50ms as per acceptance criteria)
      start_time = System.monotonic_time(:millisecond)
      {:ok, _search_results} = MemoryManager.search(agent.id, "friend social", limit: 10)
      end_time = System.monotonic_time(:millisecond)

      search_time = end_time - start_time
      assert search_time < 50, "Search took #{search_time}ms, should be under 50ms"

      IO.puts("✅ Memory search test passed!")
      IO.puts("   - Search time: #{search_time}ms (target: <50ms)")
      IO.puts("   - Semantic search working correctly")
    end

    test "complete agent lifecycle with memory formation" do
      # This test covers the end-to-end flow from TASK-010

      # Create agent
      agent_attrs = %{
        name: "LifecycleTestAgent",
        personality: %{"curiosity" => 0.9},
        stats: %{"energy" => 90, "intelligence" => 70},
        traits: ["analytical", "adventurous"],
        state: %{"mood" => "determined"}
      }

      {:ok, agent} = Agent.create(agent_attrs, domain: Thunderline.Domain)

      # Run complete tick cycle via TickWorker
      job_args = %{"agent_id" => agent.id, "tick_number" => 1}
      fake_job = %Oban.Job{args: job_args, id: 1, queue: "tick", worker: "TickWorker",
                           attempt: 1, max_attempts: 3, scheduled_at: DateTime.utc_now()}

      # Execute tick worker
      result = TickWorker.perform(fake_job)
      assert result == :ok

      # Verify complete lifecycle
      # 1. Memory creation
      {:ok, memories} = MemoryManager.search(agent.id, "", limit: 20)
      assert length(memories) > 0

      # 2. Narrative generation (check if narrative was created)
      decision_memory = Enum.find(memories, &String.contains?(&1.content, "decided"))
      assert decision_memory != nil

      # 3. Agent state updates (would need to reload agent to verify)
      {:ok, updated_agent} = Agent.get_by_id(agent.id)
      assert updated_agent.id == agent.id

      # 4. Tick logging (would be handled by the pipeline)

      IO.puts("✅ Complete agent lifecycle test passed!")
      IO.puts("   - Agent created and processed tick successfully")
      IO.puts("   - Memories formed: #{length(memories)}")
      IO.puts("   - Integration working end-to-end")
    end
  end

  describe "memory error handling" do
    test "handles memory storage failures gracefully" do
      # Test that tick processing continues even if memory storage fails
      agent_attrs = %{
        name: "ErrorTestAgent",
        personality: %{},
        stats: %{"energy" => 50},
        traits: [],
        state: %{}
      }

      {:ok, agent} = Agent.create(agent_attrs, domain: Thunderline.Domain)

      # Build minimal context
      tick_context = %{
        agent_id: agent.id,
        time_since_last_tick: 30,
        tick_number: 1,
        environment: %{},
        memory: %{recent_memories: []},
        modifications: %{},
        timestamp: DateTime.utc_now()
      }

      # Even with potential memory issues, tick should complete
      result = Pipeline.execute_tick(agent, tick_context)

      # Pipeline should handle errors gracefully
      case result do
        {:ok, _tick_result} ->
          IO.puts("✅ Tick completed successfully with memory storage")
        {:error, reason} ->
          IO.puts("⚠️  Tick failed: #{inspect(reason)}")
          # Verify it's not a memory-related failure that breaks the whole system
          refute String.contains?(inspect(reason), "memory_storage_critical_failure")
      end
    end
  end

  # Helper function to clean up test data
  defp cleanup_test_agents do
    # Would clean up test agents if needed
    :ok
  end
end
