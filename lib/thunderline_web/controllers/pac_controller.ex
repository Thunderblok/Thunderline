defmodule ThunderlineWeb.PACController do
  use ThunderlineWeb, :controller

  alias Thunderline.PAC.Agent
  alias Thunderline.Tick.Pipeline

  action_fallback ThunderlineWeb.FallbackController

  def create_agent(conn, %{"name" => name, "zone_id" => zone_id} = params) do
    agent_params = %{
      name: name,
      zone_id: zone_id,
      description: params["description"],
      stats: params["stats"] || %{},
      traits: params["traits"] || %{},
      ai_config: params["ai_config"] || %{}
    }

    case Agent.create(agent_params, domain: Thunderline.Domain) do
      {:ok, agent} ->
        conn
        |> put_status(:created)
        |> json(%{data: agent})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: error})
    end
  end

  def get_agent(conn, %{"id" => id}) do
    case Agent.get_by_id(id, load: [:zone, :mods], domain: Thunderline.Domain) do
      {:ok, agent} ->
        json(conn, %{data: agent})

      {:error, %Ash.Error.Query.NotFound{}} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Agent not found"})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: error})
    end
  end

  def update_agent(conn, %{"id" => id} = params) do
    with {:ok, agent} <- Agent.get_by_id(id, domain: Thunderline.Domain),
         {:ok, updated_agent} <- Agent.update(agent, params, domain: Thunderline.Domain) do
      json(conn, %{data: updated_agent})
    else
      {:error, %Ash.Error.Query.NotFound{}} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Agent not found"})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: error})
    end
  end

  def tick_agent(conn, %{"id" => id}) do
    with {:ok, agent} <- Agent.get_by_id(id, load: [:zone, :mods], domain: Thunderline.Domain) do
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

      case Pipeline.execute_tick(agent, tick_context) do
        {:ok, result} ->
          json(conn, %{
            data: %{
              agent_id: agent.id,
              tick_result: result,
              status: "success"
            }
          })

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: reason})
      end
    else
      {:error, %Ash.Error.Query.NotFound{}} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Agent not found"})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: error})
    end
  end
end
