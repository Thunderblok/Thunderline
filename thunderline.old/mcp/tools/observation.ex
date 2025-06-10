defmodule Thunderline.MCP.Tools.Observation do
  @moduledoc """
  Tool for observing the current environment and context.

  Allows PACs to gather information about their surroundings,
  other PACs, and environmental conditions.
  """

  @behaviour Thunderline.MCP.Tool

  alias Thunderline.{PAC, Repo}
  alias Thunderline.PAC.Zone

  @impl true
  def execute(params) do
    %{
      "pac_id" => pac_id,
      "scope" => scope
    } = params

    case scope do
      "environment" -> observe_environment(pac_id)
      "self" -> observe_self(pac_id)
      "social" -> observe_social_context(pac_id)
      "zone" -> observe_zone(pac_id)
      _ -> {:error, {:invalid_scope, scope}}
    end
  end

  defp observe_environment(pac_id) do
    with {:ok, pac} <- get_pac(pac_id),
         {:ok, zone} <- get_zone(pac.zone_id) do

      observation = %{
        type: "environment",
        location: zone.name,
        zone_type: zone.zone_type,
        atmosphere: zone.rules["atmosphere"] || "neutral",
        available_resources: zone.rules["resources"] || [],
        restrictions: zone.rules["restrictions"] || [],
        description: zone.description
      }

      {:ok, observation}
    end
  end

  defp observe_self(pac_id) do
    with {:ok, pac} <- get_pac(pac_id) do
      observation = %{
        type: "self",
        name: pac.name,
        stats: pac.stats,
        state: pac.state,
        traits: pac.traits,
        energy_level: categorize_energy(pac.stats["energy"]),
        mood: pac.state["mood"],
        activity: pac.state["activity"],
        goals: pac.state["goals"] || []
      }

      {:ok, observation}
    end
  end

  defp observe_social_context(pac_id) do
    with {:ok, pac} <- get_pac(pac_id),
         {:ok, zone} <- get_zone(pac.zone_id) do

      other_pacs = get_other_pacs_in_zone(zone.id, pac_id)

      observation = %{
        type: "social",
        zone: zone.name,
        other_pacs_count: length(other_pacs),
        other_pacs: Enum.map(other_pacs, &summarize_pac/1),
        social_opportunities: identify_social_opportunities(other_pacs, pac),
        interaction_history: get_recent_interactions(pac_id)
      }

      {:ok, observation}
    end
  end

  defp observe_zone(pac_id) do
    with {:ok, pac} <- get_pac(pac_id),
         {:ok, zone} <- get_zone(pac.zone_id) do

      zone_stats = calculate_zone_stats(zone.id)

      observation = %{
        type: "zone",
        name: zone.name,
        description: zone.description,
        zone_type: zone.zone_type,
        rules: zone.rules,
        capacity: zone.capacity,
        current_occupancy: zone_stats.pac_count,
        activity_level: zone_stats.activity_level,
        recent_events: get_recent_zone_events(zone.id)
      }

      {:ok, observation}
    end
  end

  # Helper functions

  defp get_pac(pac_id) do
    case Repo.get(PAC, pac_id) do
      nil -> {:error, :pac_not_found}
      pac -> {:ok, pac}
    end
  end

  defp get_zone(zone_id) when is_nil(zone_id), do: {:error, :no_zone}
  defp get_zone(zone_id) do
    case Repo.get(Zone, zone_id) do
      nil -> {:error, :zone_not_found}
      zone -> {:ok, zone}
    end
  end

  defp get_other_pacs_in_zone(zone_id, excluding_pac_id) do
    PAC
    |> Ash.Query.filter(zone_id == ^zone_id and id != ^excluding_pac_id)
    |> Ash.Query.limit(10)  # Limit for performance
    |> Repo.all()
  end

  defp summarize_pac(pac) do
    %{
      name: pac.name,
      activity: pac.state["activity"] || "idle",
      mood: pac.state["mood"] || "neutral",
      traits: Enum.take(pac.traits, 3),  # Show only top 3 traits
      approachable: pac.stats["social"] > 50
    }
  end

  defp identify_social_opportunities(other_pacs, pac) do
    opportunities = []

    # Check for PACs with high social stats
    social_pacs = Enum.filter(other_pacs, &(&1.stats["social"] > 60))
    opportunities = if length(social_pacs) > 0 do
      ["high_social_pacs_present" | opportunities]
    else
      opportunities
    end

    # Check for PACs with similar interests/traits
    similar_pacs = Enum.filter(other_pacs, &has_similar_traits?(&1, pac))
    opportunities = if length(similar_pacs) > 0 do
      ["similar_interests_detected" | opportunities]
    else
      opportunities
    end

    # Check for collaborative activities
    collaborating_pacs = Enum.filter(other_pacs, &(&1.state["activity"] in ["collaborating", "creating"]))
    opportunities = if length(collaborating_pacs) > 0 do
      ["collaboration_opportunities" | opportunities]
    else
      opportunities
    end

    opportunities
  end

  defp has_similar_traits?(pac1, pac2) do
    common_traits = MapSet.intersection(
      MapSet.new(pac1.traits),
      MapSet.new(pac2.traits)
    )

    MapSet.size(common_traits) >= 2
  end

  defp get_recent_interactions(pac_id) do
    # Placeholder - would query interaction logs
    []
  end

  defp calculate_zone_stats(zone_id) do
    pac_count = PAC
    |> Ash.Query.filter(zone_id == ^zone_id)
    |> Repo.aggregate(:count)

    # Calculate activity level based on recent actions
    activity_level = case pac_count do
      0 -> "quiet"
      n when n < 3 -> "low"
      n when n < 7 -> "moderate"
      _ -> "high"
    end

    %{
      pac_count: pac_count,
      activity_level: activity_level
    }
  end

  defp get_recent_zone_events(_zone_id) do
    # Placeholder - would query recent zone events/logs
    []
  end

  defp categorize_energy(energy) when energy > 80, do: "high"
  defp categorize_energy(energy) when energy > 50, do: "medium"
  defp categorize_energy(energy) when energy > 20, do: "low"
  defp categorize_energy(_), do: "depleted"
end
