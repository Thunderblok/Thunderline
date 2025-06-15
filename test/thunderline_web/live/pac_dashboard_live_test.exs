defmodule ThunderlineWeb.PacDashboardLiveTest do
  use ThunderlineWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Thunderline.PAC.Agent

  # Helper to create a PAC, assuming a simple creation function
  defp create_pac(attrs \\ %{}) do
    default_attrs = %{
      name: "TestPAC-#{System.unique_integer([:positive])}",
      description: "A test PAC",
      traits: %{stubborn: true},
      # Ensure stats has expected keys
      stats: %{"energy" => 75, "mood" => "curious"}
    }

    final_attrs = Map.merge(default_attrs, attrs)
    {:ok, pac} = Agent.create(final_attrs)
    pac
  end

  describe "PacDashboardLive initial rendering" do
    test "renders main title and dev panel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/pac_dashboard")

      assert has_element?(view, "h1", "PAC Dashboard")
      assert has_element?(view, "#dev-panel h2", "Under the Hood Dev Panel")
    end
  end

  describe "PacDashboardLive displaying PACs" do
    test "shows created PACs in the list", %{conn: conn} do
      pac = create_pac(%{name: "Binky"})
      {:ok, view, _html} = live(conn, ~p"/pac_dashboard")

      assert has_element?(view, "#pac-list-view", pac.name)
      # A more specific assertion if needed:
      assert has_element?(view, "#pac-list-view .block h3", pac.name)
    end

    test "shows multiple PACs", %{conn: conn} do
      pac1 = create_pac(%{name: "PacAlpha"})
      pac2 = create_pac(%{name: "PacBeta"})

      {:ok, view, _html} = live(conn, ~p"/pac_dashboard")

      assert has_element?(view, "#pac-list-view", pac1.name)
      assert has_element?(view, "#pac-list-view", pac2.name)
    end

    test "shows placeholder if no PACs exist", %{conn: conn} do
      # Ensure no PACs are present from other tests if tests are not sandboxed for DB
      # This might require specific cleanup or a sandbox mode if Agent.create writes to a DB
      # For now, assume a clean state or that list_active is effective.
      {:ok, view, _html} = live(conn, ~p"/pac_dashboard")
      assert has_element?(view, "#pac-list-view", "No active PACs found.")
    end
  end

  describe "PacDashboardLive dev panel interaction" do
    test "selects PAC and triggers manual tick", %{conn: conn} do
      pac = create_pac(%{name: "TickMe"})

      {:ok, view, _html} = live(conn, ~p"/pac_dashboard")

      # Simulate selecting the PAC in the dev panel dropdown
      view =
        view
        |> element("#dev-pac-select")
        |> render_change(%{value: pac.id})

      assert has_element?(view, "#dev-panel", "Raw Ash Resource Dump: #{pac.name}")
      assert has_element?(view, "button[phx-click=\"trigger_manual_tick\"]", pac.id)

      # Simulate clicking the "Trigger Manual Tick" button
      # Ensure the Agent.tick function is mockable or handles unknown IDs gracefully if it's a real call.
      # For this test, we assume Agent.tick will return {:ok, _} or {:error, _}
      # and that it's safe to call in a test environment.

      # Mocking Agent.tick if it's complex or has many side effects:
      # import Mox
      # expect(Thunderline.PAC.AgentMock, :tick, fn %{id: ^pac.id} -> {:ok, pac} end)
      # For now, assume direct call is okay.

      view =
        view
        |> element("button[phx-click=\"trigger_manual_tick\"]")
        |> render_click()

      # Check for success flash message
      # The flash message might appear on the next render cycle or be part of the current one.
      # Phoenix.LiveViewTest often captures it directly.
      assert render(view) =~ "Manual tick triggered successfully for PAC ID: #{pac.id}"
      # Or, if flash messages are handled specifically by LiveFlash:
      # assert has_element?(view, ".alert-info", "Manual tick triggered successfully")
    end

    test "dev panel shows selected PAC data", %{conn: conn} do
      pac = create_pac(%{name: "DataDumpPAC", stats: %{"energy" => 99, "mood" => "analytical"}})
      {:ok, view, _html} = live(conn, ~p"/pac_dashboard")

      view =
        view
        |> element("#dev-pac-select")
        |> render_change(%{value: pac.id})

      rendered_html = render(view)
      assert rendered_html =~ "Raw Ash Resource Dump: #{pac.name}"
      # Check if ID is in the dump
      assert rendered_html =~ inspect(pac.id)
      # Check if a specific stat/mood is in the dump
      assert rendered_html =~ "analytical"
      assert rendered_html =~ ":energy"
      assert rendered_html =~ "99"
    end
  end
end
