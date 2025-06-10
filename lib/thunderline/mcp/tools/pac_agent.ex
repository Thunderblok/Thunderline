defmodule Thunderline.MCP.Tools.PACAgent do
  @moduledoc """
  MCP tools for PAC agent operations.
  """

  alias Thunderline.PAC.{Agent, Manager}

  def create_agent(arguments, _session_id) do
    name = Map.get(arguments, "name")
    zone_id = Map.get(arguments, "zone_id")
    description = Map.get(arguments, "description", "")

    opts = if description != "", do: [description: description], else: []

    case Manager.create_agent(name, zone_id, opts) do
      {:ok, agent} ->
        {:ok, %{
          id: agent.id,
          name: agent.name,
          description: agent.description,
          zone_id: agent.zone_id,
          stats: agent.stats,
          traits: agent.traits,
          state: agent.state
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_agent(arguments, _session_id) do
    agent_id = Map.get(arguments, "agent_id")

    case Manager.get_agent(agent_id) do
      {:ok, agent} ->
        {:ok, %{
          id: agent.id,
          name: agent.name,
          description: agent.description,
          zone_id: agent.zone_id,
          stats: agent.stats,
          traits: agent.traits,
          state: agent.state,
          zone: if(agent.zone, do: %{
            id: agent.zone.id,
            name: agent.zone.name,
            properties: agent.zone.properties
          }),
          mods: Enum.map(agent.mods || [], fn mod ->
            %{
              id: mod.id,
              name: mod.name,
              type: mod.mod_type,
              active: mod.active,
              effects: mod.effects
            }
          end)
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def update_agent(arguments, _session_id) do
    agent_id = Map.get(arguments, "agent_id")
    changes = Map.get(arguments, "changes")

    case Manager.update_agent(agent_id, changes) do
      {:ok, agent} ->
        {:ok, %{
          id: agent.id,
          name: agent.name,
          stats: agent.stats,
          traits: agent.traits,
          state: agent.state,
          updated_at: agent.updated_at
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def tick_agent(arguments, _session_id) do
    agent_id = Map.get(arguments, "agent_id")

    case Manager.tick_agent(agent_id) do
      {:ok, agent} ->
        {:ok, %{
          id: agent.id,
          name: agent.name,
          stats: agent.stats,
          state: agent.state,
          tick_processed: true
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
