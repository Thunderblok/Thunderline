defmodule ThunderlineWeb.TickController do
  use ThunderlineWeb, :controller

  alias Thunderline.Tick.Orchestrator

  action_fallback ThunderlineWeb.FallbackController

  def status(conn, _params) do
    status = Orchestrator.get_status()
    json(conn, %{data: status})
  end

  def start_simulation(conn, params) do
    # 30 seconds default
    interval = params["interval"] || 30_000
    max_concurrent = params["max_concurrent"] || 10

    case Orchestrator.start_simulation(interval: interval, max_concurrent: max_concurrent) do
      {:ok, info} ->
        json(conn, %{
          data: %{
            status: "started",
            interval: interval,
            max_concurrent: max_concurrent,
            info: info
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def stop_simulation(conn, _params) do
    case Orchestrator.stop_simulation() do
      {:ok, info} ->
        json(conn, %{
          data: %{
            status: "stopped",
            info: info
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
end
