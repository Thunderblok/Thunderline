defmodule ThunderlineWeb.Presence do
  @moduledoc """
  Phoenix Presence for tracking agent presence in zones.

  Provides real-time presence tracking for agents within zones,
  inspired by Mozilla Reticulum's presence management system.
  """

  use Phoenix.Presence,
    otp_app: :thunderline,
    pubsub_server: Thunderline.PubSub

  # Optional: define custom presence functions

  @doc """
  Track an agent's presence in a zone with metadata.
  """
  def track_agent_in_zone(zone_id, agent_id, metadata \\ %{}) do
    track(
      self(),
      "zone:#{zone_id}",
      agent_id,
      Map.merge(
        %{
          joined_at: DateTime.utc_now(),
          agent_id: agent_id
        },
        metadata
      )
    )
  end

  @doc """
  Untrack an agent from a zone.
  """
  def untrack_agent_from_zone(zone_id, agent_id) do
    untrack(self(), "zone:#{zone_id}", agent_id)
  end

  @doc """
  Get all agents present in a zone.
  """
  def get_zone_agents(zone_id) do
    list("zone:#{zone_id}")
    |> Enum.map(fn {agent_id, %{metas: [meta | _]}} ->
      %{
        agent_id: agent_id,
        joined_at: meta.joined_at,
        metadata: Map.drop(meta, [:joined_at, :agent_id])
      }
    end)
  end

  @doc """
  Get the count of agents in a zone.
  """
  def get_zone_agent_count(zone_id) do
    "zone:#{zone_id}"
    |> list()
    |> map_size()
  end
end
