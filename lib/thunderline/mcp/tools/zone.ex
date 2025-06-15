defmodule Thunderline.MCP.Tools.Zone do
  @moduledoc """
  MCP tools for zone operations.
  """

  alias Thunderline.PAC.Zone

  def create(arguments, _session_id) do
    name = Map.get(arguments, "name")
    description = Map.get(arguments, "description", "")
    size = Map.get(arguments, "size", 100)

    case Zone.create(name, description: description, size: size) do
      {:ok, zone} ->
        {:ok,
         %{
           id: zone.id,
           name: zone.name,
           description: zone.description,
           size: zone.size,
           max_agents: zone.max_agents,
           properties: zone.properties,
           rules: zone.rules
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list(_arguments, _session_id) do
    case Zone.list_all() do
      {:ok, zones} ->
        formatted_zones =
          Enum.map(zones, fn zone ->
            %{
              id: zone.id,
              name: zone.name,
              description: zone.description,
              size: zone.size,
              max_agents: zone.max_agents,
              agent_count: length(zone.agents || []),
              properties: zone.properties
            }
          end)

        {:ok,
         %{
           zones: formatted_zones,
           count: length(formatted_zones)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_info(arguments, _session_id) do
    zone_id = Map.get(arguments, "zone_id")

    case Zone.get_by_id(zone_id, load: [:agents]) do
      {:ok, zone} ->
        {:ok,
         %{
           id: zone.id,
           name: zone.name,
           description: zone.description,
           size: zone.size,
           max_agents: zone.max_agents,
           properties: zone.properties,
           rules: zone.rules,
           agents:
             Enum.map(zone.agents, fn agent ->
               %{
                 id: agent.id,
                 name: agent.name,
                 state: agent.state,
                 stats: agent.stats
               }
             end)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
