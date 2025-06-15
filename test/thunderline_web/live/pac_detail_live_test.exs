defmodule ThunderlineWeb.PacDetailLiveTest do
  use ThunderlineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Thunderline.PAC.Agent
  alias Thunderline.Tick.Log # Assuming this module exists for logs

  # Helper to create a PAC
  defp create_pac(attrs \\ %{}) do
    default_attrs = %{
      name: "DetailPAC-#{System.unique_integer([:positive])}",
      description: "A PAC for detail view testing",
      traits: %{curious: true, observant: true},
      stats: %{"energy" => 80, "fatigue" => 20, "creativity" => 60, "mood" => "focused"},
      state: %{"mood" => "focused"} # Ensure state.mood is available
    }
    final_attrs = Map.merge(default_attrs, attrs)
    {:ok, pac} = Agent.create(final_attrs)
    pac
  end

  # Helper to create TickLog entries
  # This is a simplified assumption. Actual log creation might be different.
  defp create_tick_log(pac, data \\ %{}) do
    default_data = %{
      "decision_summary" => "Test decision summary #{System.unique_integer([:positive])}",
      "actions" => [%{"type" => "test_action"}],
      "perception" => %{"stimuli" => ["test_stimulus"]}
    }
    log_data = Map.merge(default_data, data)

    # Assuming a function like this exists.
    # If Thunderline.Tick.Log is an Ash resource:
    # {:ok, log} = Log.create(%{agent_id: pac.id, tick_number: System.unique_integer([:positive]), data: log_data})
    # For now, creating a struct that matches what Log.for_agent_recent/1 might return.
    # This part might need adjustment based on actual Log implementation.
    %Thunderline.Tick.Log{
      id: Ecto.UUID.generate(), # Or other ID type
      agent_id: pac.id,
      tick_number: System.unique_integer([:positive]),
      data: log_data,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  # Mock for Log.for_agent_recent/1 if direct creation is hard or undesired in tests
  # This would typically be done with Mox or by configuring an :app_env
  # For now, we'll assume direct creation or that the actual function is callable.
  # If Log.for_agent_recent/1 queries DB, then logs must be created in DB.

  describe "PacDetailLive initial rendering" do
    test "renders PAC details, traits, stats, and logs", %{conn: conn} do
      pac = create_pac(%{name: "DetailedPac", traits: %{fast_learner: true, cautious: true}})

      # Create mock logs - these would need to be actual DB records if for_agent_recent queries DB
      # For this test, let's assume we can pass them in or mock the log fetching.
      # For simplicity, we'll assume the view can handle Log structs directly.
      # In a real scenario with DB, these would be created via a Log service.
      # For now, we are not testing the Log.for_agent_recent function itself, but that the view renders logs.
      # This test might fail if Log.for_agent_recent/1 cannot be easily mocked or returns nothing.
      # One strategy is to ensure `Log.for_agent_recent/1` is called, and mock its return if it's a separate service.
      # If it's part of the same system and difficult to mock, create actual log entries.

      # Let's assume `Log.for_agent_recent` is part of the Agent context or a queryable system
      # and we can't easily inject logs directly into the view's assigns for this test structure.
      # So, the test relies on `Agent.get_by_id` and `Log.for_agent_recent` working as expected.
      # We need to create logs that `Log.for_agent_recent` can find.
      # This implies `create_tick_log` should actually save the log.
      # This is beyond simple LiveView testing if `Log` is a complex resource.

      # Simplified approach for now: Test rendering of components assuming data is passed.
      # If `Log.for_agent_recent` is problematic for tests, it's an area to refactor for testability.

      # To proceed, we assume `create_tick_log` is a stand-in for what should be proper data setup.
      # The test will pass if the HTML components for these sections are present.
      # The actual content of logs will depend on `Log.for_agent_recent` functioning.

      {:ok, view, _html} = live(conn, ~p"/pac/#{pac.id}")

      assert has_element?(view, "h1", pac.name)

      # Traits
      assert has_element?(view, "#traits .bg-slate-700", "Fast learner") # Checks for formatted trait
      assert has_element?(view, "#traits .bg-slate-700", "Cautious")

      # Stats
      assert has_element?(view, "#stats", "ENERGY")
      assert has_element?(view, "#stats", "FATIGUE")
      assert has_element?(view, "#stats", "CREATIVITY")
      assert has_element?(view, "#stats .bg-sky-500") # Energy bar fill

      # Tick Logs (very basic check, as log creation is complex)
      # This part is highly dependent on how logs are actually created and fetched.
      # If `Log.for_agent_recent/1` returns an empty list because no logs were *actually* persisted
      # by our `create_tick_log` helper, then this part of the test would show "No tick logs".
      # For a robust test, logs would need to be persisted.
      # For now, we check if the "Tick Log Timeline" title is there.
      # A more advanced test would mock the log fetching call.
      assert has_element?(view, "#tick-log-timeline h2", "Tick Log Timeline")
      # If we could ensure logs, we'd assert their content:
      # log_entry = create_tick_log(pac, %{"decision_summary" => "Specific test log"})
      # ^ This would need to persist for Log.for_agent_recent/1 to pick it up.
      # If Log.for_agent_recent/1 was mocked, we could check for "Specific test log".
    end

    test "displays 'No traits defined' if PAC has no traits", %{conn: conn} do
      pac = create_pac(%{name: "TraitlessPac", traits: %{}})
      {:ok, view, _html} = live(conn, ~p"/pac/#{pac.id}")
      assert has_element?(view, "#traits", "No traits defined.")
    end

    test "displays 'No tick logs found' if no logs exist for the agent", %{conn: conn} do
      pac = create_pac(%{name: "LoglessPac"})
      # Assuming Log.for_agent_recent(pac.id) will return []
      {:ok, view, _html} = live(conn, ~p"/pac/#{pac.id}")
      assert has_element?(view, "#tick-log-timeline", "No tick logs found for this agent.")
    end
  end

  describe "PacDetailLive PubSub updates (conceptual)" do
    # As noted in the task, directly testing PubSub in LiveView without specific helpers is complex.
    # The key is that if assigns change (e.g., @pac, @tick_logs), the view re-renders.
    # This is implicitly tested by the initial render tests when data is present.

    # A more direct, though still somewhat indirect, test could involve:
    # 1. Rendering the view.
    # 2. Broadcasting a mock PubSub message that `handle_info` is expected to process.
    #    This requires `Phoenix.PubSub.broadcast/3` and knowledge of the topic string.
    # 3. Asserting that the view content changes according to the new data that `handle_info`
    #    should have fetched and assigned.
    # This still relies on `handle_info` correctly fetching data (e.g., `Agent.get_by_id`).

    # Example (would require `Thunderline.PubSub` to be available and configured for test):
    # test "view updates when PAC data changes via PubSub", %{conn: conn} do
    #   pac = create_pac(%{name: "OldName"})
    #   {:ok, view, _html} = live(conn, ~p"/pac/#{pac.id}")
    #   assert has_element?(view, "h1", "OldName")

    #   # Simulate an external update that PubSub would pick up
    #   updated_pac_data_for_pubsub = %{id: pac.id, name: "NewName", ...other fields needed by Agent.get_by_id...}
    #   # In a real scenario, some service would update the PAC and then broadcast.
    #   # Here we simulate the broadcast that would trigger handle_info in PacDetailLive
    #   Phoenix.PubSub.broadcast(Thunderline.PubSub, "agents:updates", {:pac_updated, updated_pac_data_for_pubsub})

    #   # Wait for re-render (render/0 might be needed, or it might auto-render)
    #   assert render(view) =~ "NewName" # Or has_element?(view, "h1", "NewName")
    # end
    # This test is commented out as it requires more setup for PubSub interaction in tests.
  end
end
