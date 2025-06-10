defmodule Thunderline.MCP.Server do
  @moduledoc """
  Model Context Protocol (MCP) Server for Thunderline.

  Provides a standardized interface for AI agents to interact with
  Thunderline's capabilities through tools and resources.
  """

  use GenServer
  require Logger

  alias Thunderline.MCP.{ToolRegistry, Session}

  @mcp_port Application.compile_env(:thunderline, [:mcp, :port], 3001)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Start the MCP server on the configured port
    {:ok, listener} = :ranch.start_listener(
      :mcp_server,
      :ranch_tcp,
      [{:port, @mcp_port}],
      Thunderline.MCP.ProtocolHandler,
      []
    )

    Logger.info("MCP Server started on port #{@mcp_port}")

    state = %{
      listener: listener,
      sessions: %{},
      tools: ToolRegistry.list_tools()
    }

    {:ok, state}
  end

  # Client API

  def list_tools do
    GenServer.call(__MODULE__, :list_tools)
  end

  def call_tool(tool_name, arguments, session_id \\ nil) do
    GenServer.call(__MODULE__, {:call_tool, tool_name, arguments, session_id})
  end

  def create_session(client_info) do
    GenServer.call(__MODULE__, {:create_session, client_info})
  end

  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  # Server Callbacks

  def handle_call(:list_tools, _from, state) do
    tools = ToolRegistry.list_tools()
    {:reply, {:ok, tools}, %{state | tools: tools}}
  end

  def handle_call({:call_tool, tool_name, arguments, session_id}, _from, state) do
    case ToolRegistry.call_tool(tool_name, arguments, session_id) do
      {:ok, result} ->
        # Log the tool call
        log_tool_call(tool_name, arguments, result, session_id)
        {:reply, {:ok, result}, state}

      {:error, reason} ->
        Logger.warning("Tool call failed: #{tool_name} - #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:create_session, client_info}, _from, state) do
    session_id = UUID.uuid4()
    session = Session.create(session_id, client_info)

    new_sessions = Map.put(state.sessions, session_id, session)
    new_state = %{state | sessions: new_sessions}

    Logger.info("MCP session created: #{session_id}")
    {:reply, {:ok, session}, new_state}
  end

  def handle_call({:get_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil -> {:reply, {:error, :session_not_found}, state}
      session -> {:reply, {:ok, session}, state}
    end
  end

  # Private Functions

  defp log_tool_call(tool_name, arguments, result, session_id) do
    log_entry = %{
      tool_name: tool_name,
      arguments: arguments,
      result: result,
      session_id: session_id,
      timestamp: DateTime.utc_now()
    }

    # This could be stored in the database or sent to a logging service
    Logger.debug("MCP tool call: #{inspect(log_entry)}")
  end
end
