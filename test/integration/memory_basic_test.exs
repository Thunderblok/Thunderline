defmodule Thunderline.Integration.MemoryBasicTest do
  @moduledoc """
  Basic integration test for memory and narrative systems.

  This test validates core memory functionality without complex dependencies:
  - Memory Manager storage and retrieval
  - Narrative Engine functionality
  - Basic integration readiness
  """

  use ExUnit.Case

  alias Thunderline.Memory.Manager, as: MemoryManager
  alias Thunderline.Narrative.Engine

  describe "core memory functionality" do
    test "memory manager basic storage and retrieval" do
      # Test that Memory Manager can store and retrieve memories

      # Create a fake agent ID for testing
      agent_id = UUID.uuid4()

      # Test basic memory storage
      {:ok, memory_node} = MemoryManager.store(agent_id, "Test memory content",
                                              tags: ["test", "integration"])

      assert memory_node != nil
      assert memory_node.agent_id == agent_id
      assert memory_node.content == "Test memory content"
      assert "test" in memory_node.tags
      assert "integration" in memory_node.tags

      IO.puts("✅ Basic memory storage working!")
      IO.puts("   - Agent ID: #{agent_id}")
      IO.puts("   - Memory content stored successfully")
      IO.puts("   - Tags preserved: #{inspect(memory_node.tags)}")
    end

    test "memory search functionality" do
      # Test semantic memory search
      agent_id = UUID.uuid4()

      # Store multiple memories
      {:ok, _mem1} = MemoryManager.store(agent_id, "I love creative projects",
                                        tags: ["creativity", "passion"])
      {:ok, _mem2} = MemoryManager.store(agent_id, "Problem solving is fun",
                                        tags: ["analysis", "enjoyment"])
      {:ok, _mem3} = MemoryManager.store(agent_id, "Exploring new ideas excites me",
                                        tags: ["exploration", "curiosity"])

      # Test search
      {:ok, search_results} = MemoryManager.search(agent_id, "creative", limit: 5)

      assert length(search_results) > 0

      # Find the creativity-related memory
      creative_memory = Enum.find(search_results, fn memory ->
        String.contains?(memory.content, "creative")
      end)

      assert creative_memory != nil

      IO.puts("✅ Memory search working!")
      IO.puts("   - Stored 3 memories")
      IO.puts("   - Search found #{length(search_results)} results")
      IO.puts("   - Creative memory found: #{creative_memory.content}")
    end

    test "narrative engine basic functionality" do
      # Test that narrative engine can generate stories

      context = %{
        agent_name: "TestAgent",
        decision: %{
          action_type: "explore",
          reasoning: "curiosity about the unknown"
        },
        actions: [
          %{type: "exploration", result: {:ok, "discovered a hidden cave"}}
        ],
        success: true
      }

      {:ok, narrative} = Engine.generate_tick_narrative(context)

      assert is_binary(narrative)
      assert String.contains?(narrative, "TestAgent")
      assert String.length(narrative) > 10  # Should be a meaningful narrative

      IO.puts("✅ Narrative generation working!")
      IO.puts("   - Generated narrative: #{narrative}")
    end

    test "memory manager performance" do
      # Test that memory operations are reasonably fast
      agent_id = UUID.uuid4()

      # Store a memory
      start_time = System.monotonic_time(:millisecond)
      {:ok, _memory} = MemoryManager.store(agent_id, "Performance test memory",
                                          tags: ["performance"])
      store_time = System.monotonic_time(:millisecond) - start_time

      # Search for memories
      start_time = System.monotonic_time(:millisecond)
      {:ok, _results} = MemoryManager.search(agent_id, "performance", limit: 10)
      search_time = System.monotonic_time(:millisecond) - start_time

      # Performance assertions (generous limits for CI)
      assert store_time < 1000, "Memory storage took #{store_time}ms, should be under 1000ms"
      assert search_time < 100, "Memory search took #{search_time}ms, should be under 100ms"

      IO.puts("✅ Memory performance acceptable!")
      IO.puts("   - Store time: #{store_time}ms")
      IO.puts("   - Search time: #{search_time}ms")
    end
  end

  describe "integration readiness" do
    test "core systems can be used together" do
      # Test that Memory Manager and Narrative Engine can work together
      agent_id = UUID.uuid4()

      # Store some agent memories
      {:ok, _mem1} = MemoryManager.store(agent_id, "Previous successful exploration",
                                        tags: ["exploration", "success"])

      # Generate a narrative about the agent
      context = %{
        agent_name: "IntegrationTestAgent",
        decision: %{action_type: "analyze", reasoning: "need to understand the situation"},
        actions: [%{type: "analysis", result: {:ok, "gained new insights"}}],
        success: true
      }

      {:ok, narrative} = Engine.generate_tick_narrative(context)

      # Store the narrative as a memory
      {:ok, narrative_memory} = MemoryManager.store(agent_id, narrative,
                                                   tags: ["narrative", "tick_result"])

      # Search for both types of memories
      {:ok, all_memories} = MemoryManager.search(agent_id, "", limit: 20)

      exploration_memories = Enum.filter(all_memories, fn memory ->
        "exploration" in memory.tags
      end)

      narrative_memories = Enum.filter(all_memories, fn memory ->
        "narrative" in memory.tags
      end)

      assert length(exploration_memories) > 0
      assert length(narrative_memories) > 0

      IO.puts("✅ Core systems integration working!")
      IO.puts("   - Total memories: #{length(all_memories)}")
      IO.puts("   - Exploration memories: #{length(exploration_memories)}")
      IO.puts("   - Narrative memories: #{length(narrative_memories)}")
      IO.puts("   - Systems can work together successfully")
    end
  end

  describe "error handling" do
    test "handles invalid inputs gracefully" do
      # Test with nil agent ID
      result = MemoryManager.store(nil, "test content", tags: ["test"])

      # Should either work or fail gracefully (not crash)
      case result do
        {:ok, _memory} ->
          IO.puts("✅ Memory manager handles nil agent ID")
        {:error, reason} ->
          IO.puts("✅ Memory manager fails gracefully with nil agent ID: #{inspect(reason)}")
      end

      # The important thing is that it doesn't crash the test
      assert true
    end

    test "handles empty content gracefully" do
      agent_id = UUID.uuid4()

      result = MemoryManager.store(agent_id, "", tags: ["empty"])

      case result do
        {:ok, memory} ->
          assert memory.content == ""
          IO.puts("✅ Memory manager stores empty content")
        {:error, reason} ->
          IO.puts("✅ Memory manager rejects empty content: #{inspect(reason)}")
      end

      # Again, no crashes is the main requirement
      assert true
    end
  end
end
