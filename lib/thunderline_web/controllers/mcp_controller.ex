defmodule ThunderlineWeb.MCPController do
  use ThunderlineWeb, :controller

  alias Thunderline.MCP.{Server, ToolRegistry}

  action_fallback ThunderlineWeb.FallbackController

  def list_tools(conn, _params) do
    tools = ToolRegistry.list_tools()
    json(conn, %{data: tools})
  end

  def call_tool(conn, %{"name" => tool_name} = params) do
    tool_args = params["args"] || %{}
    session_id = params["session_id"] || "default"

    case Server.call_tool(session_id, tool_name, tool_args) do
      {:ok, result} ->
        json(conn, %{data: result})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end
end
