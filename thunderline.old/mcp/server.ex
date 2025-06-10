defmodule Thunderline.MCP.Server do
  @moduledoc """
  Model Context Protocol (MCP) Server for Thunderline.

  The MCP Server provides a standardized JSON-over-socket interface for
  AI agents to interact with Thunderline tools and resources. This implements
  the Model Context Protocol specification for agent-tool communication.

  Key capabilities:
  - Tool discovery and invocation
  - Resource access (PACs, Zones, Memories)
  - Prompt templates for consistent AI interactions
  - Session management and authentication
  - Real-time notifications and updates

  Think of this as the "API Gateway" for AI agents operating in Thunderline.
  """

  use GenServer
  require Logger

  alias Thunderline.MCP.{ToolRegistry, PromptManager, ResourceManager, Session}

  defstruct [
    :port,
    :socket,
    :tool_registry,
    :sessions,
    :config
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def register_tool(tool_spec) do
    GenServer.call(__MODULE__, {:register_tool, tool_spec})
  end

  def unregister_tool(tool_name) do
    GenServer.call(__MODULE__, {:unregister_tool, tool_name})
  end

  def list_tools do
    GenServer.call(__MODULE__, :list_tools)
  end

  def get_server_info do
    GenServer.call(__MODULE__, :get_server_info)
  end

  def broadcast_notification(notification) do
    GenServer.cast(__MODULE__, {:broadcast_notification, notification})
  end

  # Server Implementation

  @impl true
  def init(opts) do
    config = %{
      port: Keyword.get(opts, :port, 3001),
      max_connections: Keyword.get(opts, :max_connections, 100),
      session_timeout: Keyword.get(opts, :session_timeout, 3600), # 1 hour
      enable_auth: Keyword.get(opts, :enable_auth, true)
    }

    state = %__MODULE__{
      port: config.port,
      socket: nil,
      tool_registry: ToolRegistry.new(),
      sessions: %{},
      config: config
    }

    Logger.info("Starting MCP Server on port #{config.port}")

    {:ok, state, {:continue, :start_server}}
  end

  @impl true
  def handle_continue(:start_server, state) do
    case start_tcp_server(state.port) do
      {:ok, socket} ->
        # Register default Thunderline tools
        registry_with_defaults = register_default_tools(state.tool_registry)

        new_state = %{state |
          socket: socket,
          tool_registry: registry_with_defaults
        }

        Logger.info("MCP Server started successfully on port #{state.port}")
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to start MCP Server: #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  @impl true
  def handle_call({:register_tool, tool_spec}, _from, state) do
    case ToolRegistry.register_tool(state.tool_registry, tool_spec) do
      {:ok, new_registry} ->
        new_state = %{state | tool_registry: new_registry}
        Logger.info("Registered MCP tool: #{tool_spec.name}")
        {:reply, {:ok, tool_spec}, new_state}

      {:error, reason} ->
        Logger.error("Failed to register tool #{tool_spec.name}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:unregister_tool, tool_name}, _from, state) do
    case ToolRegistry.unregister_tool(state.tool_registry, tool_name) do
      {:ok, new_registry} ->
        new_state = %{state | tool_registry: new_registry}
        Logger.info("Unregistered MCP tool: #{tool_name}")
        {:reply, {:ok, :unregistered}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:list_tools, _from, state) do
    tools = ToolRegistry.list_tools(state.tool_registry)
    {:reply, {:ok, tools}, state}
  end

  @impl true
  def handle_call(:get_server_info, _from, state) do
    info = %{
      name: "Thunderline MCP Server",
      version: "1.0.0",
      protocol_version: "1.0",
      capabilities: [
        "tools",
        "resources",
        "prompts",
        "notifications"
      ],
      tools_count: ToolRegistry.count_tools(state.tool_registry),
      active_sessions: map_size(state.sessions),
      config: Map.drop(state.config, [:auth_secret])
    }

    {:reply, {:ok, info}, state}
  end

  @impl true
  def handle_cast({:broadcast_notification, notification}, state) do
    # Broadcast to all active sessions
    Enum.each(state.sessions, fn {_session_id, session} ->
      Session.send_notification(session, notification)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp, socket, data}, state) do
    case decode_mcp_message(data) do
      {:ok, message} ->
        handle_mcp_message(socket, message, state)

      {:error, reason} ->
        Logger.warn("Failed to decode MCP message: #{inspect(reason)}")
        send_error_response(socket, "invalid_message", "Failed to decode message")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:tcp_closed, socket}, state) do
    Logger.info("MCP client disconnected")
    # Clean up session if it exists
    new_sessions = remove_session_by_socket(state.sessions, socket)
    {:noreply, %{state | sessions: new_sessions}}
  end

  @impl true
  def handle_info({:tcp_error, socket, reason}, state) do
    Logger.warn("MCP TCP error: #{inspect(reason)}")
    new_sessions = remove_session_by_socket(state.sessions, socket)
    {:noreply, %{state | sessions: new_sessions}}
  end

  # Private implementation functions

  defp start_tcp_server(port) do
    opts = [
      :binary,
      packet: :line,
      active: true,
      reuseaddr: true
    ]

    :gen_tcp.listen(port, opts)
  end

  defp register_default_tools(registry) do
    default_tools = [
      create_pac_tool(),
      get_pac_tool(),
      update_pac_tool(),
      list_pacs_tool(),
      move_pac_tool(),
      apply_mod_tool(),
      get_zone_tool(),
      list_zones_tool(),
      force_tick_tool(),
      get_memories_tool(),
      create_memory_tool(),
      get_tick_logs_tool()
    ]

    Enum.reduce(default_tools, registry, fn tool, acc ->
      case ToolRegistry.register_tool(acc, tool) do
        {:ok, new_registry} -> new_registry
        {:error, reason} ->
          Logger.warn("Failed to register default tool #{tool.name}: #{inspect(reason)}")
          acc
      end
    end)
  end

  defp handle_mcp_message(socket, message, state) do
    case message do
      %{"method" => "initialize", "id" => id} ->
        handle_initialize(socket, id, state)

      %{"method" => "tools/list", "id" => id} ->
        handle_tools_list(socket, id, state)

      %{"method" => "tools/call", "id" => id, "params" => params} ->
        handle_tool_call(socket, id, params, state)

      %{"method" => "resources/list", "id" => id} ->
        handle_resources_list(socket, id, state)

      %{"method" => "resources/read", "id" => id, "params" => params} ->
        handle_resource_read(socket, id, params, state)

      %{"method" => "prompts/list", "id" => id} ->
        handle_prompts_list(socket, id, state)

      %{"method" => "prompts/get", "id" => id, "params" => params} ->
        handle_prompt_get(socket, id, params, state)

      _ ->
        send_error_response(socket, "method_not_found", "Unknown method")
        {:noreply, state}
    end
  end

  defp handle_initialize(socket, id, state) do
    session_id = generate_session_id()
    session = Session.new(session_id, socket)

    new_sessions = Map.put(state.sessions, session_id, session)

    response = %{
      id: id,
      result: %{
        protocol_version: "1.0",
        server_info: %{
          name: "Thunderline MCP Server",
          version: "1.0.0"
        },
        capabilities: %{
          tools: %{list_changed: true},
          resources: %{subscribe: true, list_changed: true},
          prompts: %{list_changed: true}
        }
      }
    }

    send_response(socket, response)
    {:noreply, %{state | sessions: new_sessions}}
  end

  defp handle_tools_list(socket, id, state) do
    tools = ToolRegistry.list_tools(state.tool_registry)

    response = %{
      id: id,
      result: %{
        tools: tools
      }
    }

    send_response(socket, response)
    {:noreply, state}
  end

  defp handle_tool_call(socket, id, params, state) do
    tool_name = Map.get(params, "name")
    arguments = Map.get(params, "arguments", %{})

    case ToolRegistry.get_tool(state.tool_registry, tool_name) do
      {:ok, tool} ->
        case execute_tool(tool, arguments) do
          {:ok, result} ->
            response = %{
              id: id,
              result: %{
                content: [
                  %{
                    type: "text",
                    text: Jason.encode!(result)
                  }
                ]
              }
            }
            send_response(socket, response)

          {:error, reason} ->
            send_error_response(socket, "tool_execution_failed", inspect(reason), id)
        end

      {:error, :not_found} ->
        send_error_response(socket, "tool_not_found", "Tool #{tool_name} not found", id)
    end

    {:noreply, state}
  end

  defp handle_resources_list(socket, id, state) do
    resources = ResourceManager.list_resources()

    response = %{
      id: id,
      result: %{
        resources: resources
      }
    }

    send_response(socket, response)
    {:noreply, state}
  end

  defp handle_resource_read(socket, id, params, state) do
    uri = Map.get(params, "uri")

    case ResourceManager.read_resource(uri) do
      {:ok, content} ->
        response = %{
          id: id,
          result: %{
            contents: [content]
          }
        }
        send_response(socket, response)

      {:error, reason} ->
        send_error_response(socket, "resource_not_found", inspect(reason), id)
    end

    {:noreply, state}
  end

  defp handle_prompts_list(socket, id, state) do
    prompts = PromptManager.list_prompts()

    response = %{
      id: id,
      result: %{
        prompts: prompts
      }
    }

    send_response(socket, response)
    {:noreply, state}
  end

  defp handle_prompt_get(socket, id, params, state) do
    name = Map.get(params, "name")
    arguments = Map.get(params, "arguments", %{})

    case PromptManager.get_prompt(name, arguments) do
      {:ok, prompt} ->
        response = %{
          id: id,
          result: prompt
        }
        send_response(socket, response)

      {:error, reason} ->
        send_error_response(socket, "prompt_not_found", inspect(reason), id)
    end

    {:noreply, state}
  end

  # Utility functions

  defp decode_mcp_message(data) do
    Jason.decode(data)
  end

  defp send_response(socket, response) do
    data = Jason.encode!(response) <> "\n"
    :gen_tcp.send(socket, data)
  end

  defp send_error_response(socket, code, message, id \\ nil) do
    response = %{
      id: id,
      error: %{
        code: code,
        message: message
      }
    }

    send_response(socket, response)
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp remove_session_by_socket(sessions, socket) do
    Enum.reject(sessions, fn {_id, session} ->
      Session.get_socket(session) == socket
    end)
    |> Map.new()
  end

  defp execute_tool(tool, arguments) do
    # This would dispatch to the actual tool implementation
    # For now, we'll create a simple dispatcher
    case tool.name do
      "create_pac" -> execute_create_pac_tool(arguments)
      "get_pac" -> execute_get_pac_tool(arguments)
      "update_pac" -> execute_update_pac_tool(arguments)
      "list_pacs" -> execute_list_pacs_tool(arguments)
      _ -> {:error, "Tool not implemented"}
    end
  end

  # Tool implementations (simplified)

  defp execute_create_pac_tool(args) do
    case Thunderline.PAC.Manager.create_pac(args) do
      {:ok, pac} -> {:ok, %{pac_id: pac.id, name: pac.name}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_get_pac_tool(%{"pac_id" => pac_id}) do
    case Thunderline.PAC.Manager.get_pac(pac_id) do
      {:ok, pac} -> {:ok, pac}
      {:error, reason} -> {:error, reason}
    end
  end
  defp execute_get_pac_tool(_), do: {:error, "pac_id required"}

  defp execute_update_pac_tool(args) do
    # Implementation would go here
    {:error, "Not implemented yet"}
  end

  defp execute_list_pacs_tool(_args) do
    case Thunderline.PAC.Manager.list_active_pacs() do
      {:ok, pacs} -> {:ok, pacs}
      {:error, reason} -> {:error, reason}
    end
  end

  # Default tool definitions

  defp create_pac_tool do
    %{
      name: "create_pac",
      description: "Create a new Personal Autonomous Creation (PAC)",
      input_schema: %{
        type: "object",
        properties: %{
          name: %{type: "string", description: "Name of the PAC"},
          description: %{type: "string", description: "Description of the PAC"},
          zone_id: %{type: "string", description: "Optional zone ID to place the PAC"}
        },
        required: ["name"]
      }
    }
  end

  defp get_pac_tool do
    %{
      name: "get_pac",
      description: "Get information about a specific PAC",
      input_schema: %{
        type: "object",
        properties: %{
          pac_id: %{type: "string", description: "ID of the PAC"}
        },
        required: ["pac_id"]
      }
    }
  end

  defp update_pac_tool do
    %{
      name: "update_pac",
      description: "Update PAC properties",
      input_schema: %{
        type: "object",
        properties: %{
          pac_id: %{type: "string", description: "ID of the PAC"},
          stats: %{type: "object", description: "Updated stats"},
          state: %{type: "object", description: "Updated state"}
        },
        required: ["pac_id"]
      }
    }
  end

  defp list_pacs_tool do
    %{
      name: "list_pacs",
      description: "List all active PACs",
      input_schema: %{
        type: "object",
        properties: %{}
      }
    }
  end

  defp move_pac_tool do
    %{
      name: "move_pac",
      description: "Move a PAC to a different zone",
      input_schema: %{
        type: "object",
        properties: %{
          pac_id: %{type: "string", description: "ID of the PAC"},
          zone_id: %{type: "string", description: "ID of the target zone"}
        },
        required: ["pac_id", "zone_id"]
      }
    }
  end

  defp apply_mod_tool do
    %{
      name: "apply_mod",
      description: "Apply a modification to a PAC",
      input_schema: %{
        type: "object",
        properties: %{
          pac_id: %{type: "string", description: "ID of the PAC"},
          mod_id: %{type: "string", description: "ID of the mod to apply"}
        },
        required: ["pac_id", "mod_id"]
      }
    }
  end

  defp get_zone_tool do
    %{
      name: "get_zone",
      description: "Get information about a specific zone",
      input_schema: %{
        type: "object",
        properties: %{
          zone_id: %{type: "string", description: "ID of the zone"}
        },
        required: ["zone_id"]
      }
    }
  end

  defp list_zones_tool do
    %{
      name: "list_zones",
      description: "List all available zones",
      input_schema: %{
        type: "object",
        properties: %{}
      }
    }
  end

  defp force_tick_tool do
    %{
      name: "force_tick",
      description: "Force an immediate tick for a PAC",
      input_schema: %{
        type: "object",
        properties: %{
          pac_id: %{type: "string", description: "ID of the PAC"}
        },
        required: ["pac_id"]
      }
    }
  end

  defp get_memories_tool do
    %{
      name: "get_memories",
      description: "Get memories for a PAC",
      input_schema: %{
        type: "object",
        properties: %{
          pac_id: %{type: "string", description: "ID of the PAC"},
          limit: %{type: "integer", description: "Maximum number of memories to return"}
        },
        required: ["pac_id"]
      }
    }
  end

  defp create_memory_tool do
    %{
      name: "create_memory",
      description: "Create a new memory for a PAC",
      input_schema: %{
        type: "object",
        properties: %{
          pac_id: %{type: "string", description: "ID of the PAC"},
          content: %{type: "object", description: "Memory content"},
          type: %{type: "string", description: "Type of memory"}
        },
        required: ["pac_id", "content"]
      }
    }
  end

  defp get_tick_logs_tool do
    %{
      name: "get_tick_logs",
      description: "Get tick logs for a PAC",
      input_schema: %{
        type: "object",
        properties: %{
          pac_id: %{type: "string", description: "ID of the PAC"},
          limit: %{type: "integer", description: "Maximum number of logs to return"}
        },
        required: ["pac_id"]
      }
    }
  end
end
