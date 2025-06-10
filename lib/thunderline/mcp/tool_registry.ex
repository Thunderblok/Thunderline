defmodule Thunderline.MCP.ToolRegistry do
  @moduledoc """
  Registry for MCP tools available in Thunderline.

  Manages the registration, discovery, and execution of tools
  that AI agents can use through the MCP interface.
  """

  use GenServer
  require Logger

  alias Thunderline.MCP.Tools

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Register built-in tools
    tools = register_builtin_tools()

    Logger.info("MCP Tool Registry initialized with #{map_size(tools)} tools")

    {:ok, %{tools: tools}}
  end

  # Client API

  def list_tools do
    GenServer.call(__MODULE__, :list_tools)
  end

  def get_tool(tool_name) do
    GenServer.call(__MODULE__, {:get_tool, tool_name})
  end

  def register_tool(tool_name, tool_spec) do
    GenServer.call(__MODULE__, {:register_tool, tool_name, tool_spec})
  end

  def call_tool(tool_name, arguments, session_id \\ nil) do
    GenServer.call(__MODULE__, {:call_tool, tool_name, arguments, session_id})
  end

  # Server Callbacks

  def handle_call(:list_tools, _from, state) do
    tool_list = state.tools
    |> Enum.map(fn {name, spec} ->
      %{
        name: name,
        description: spec.description,
        input_schema: spec.input_schema
      }
    end)

    {:reply, tool_list, state}
  end

  def handle_call({:get_tool, tool_name}, _from, state) do
    case Map.get(state.tools, tool_name) do
      nil -> {:reply, {:error, :tool_not_found}, state}
      tool_spec -> {:reply, {:ok, tool_spec}, state}
    end
  end

  def handle_call({:register_tool, tool_name, tool_spec}, _from, state) do
    new_tools = Map.put(state.tools, tool_name, tool_spec)
    new_state = %{state | tools: new_tools}

    Logger.info("Registered MCP tool: #{tool_name}")
    {:reply, :ok, new_state}
  end

  def handle_call({:call_tool, tool_name, arguments, session_id}, _from, state) do
    case Map.get(state.tools, tool_name) do
      nil ->
        {:reply, {:error, :tool_not_found}, state}

      tool_spec ->
        case execute_tool(tool_spec, arguments, session_id) do
          {:ok, result} -> {:reply, {:ok, result}, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  # Private Functions

  defp register_builtin_tools do
    %{
      # PAC Agent Tools
      "pac_create_agent" => %{
        description: "Create a new PAC agent",
        input_schema: %{
          type: "object",
          properties: %{
            name: %{type: "string", description: "Agent name"},
            zone_id: %{type: "string", description: "Zone ID"},
            description: %{type: "string", description: "Agent description"}
          },
          required: ["name", "zone_id"]
        },
        handler: &Tools.PACAgent.create_agent/2
      },

      "pac_get_agent" => %{
        description: "Get PAC agent information",
        input_schema: %{
          type: "object",
          properties: %{
            agent_id: %{type: "string", description: "Agent ID"}
          },
          required: ["agent_id"]
        },
        handler: &Tools.PACAgent.get_agent/2
      },

      "pac_update_agent" => %{
        description: "Update PAC agent properties",
        input_schema: %{
          type: "object",
          properties: %{
            agent_id: %{type: "string", description: "Agent ID"},
            changes: %{type: "object", description: "Changes to apply"}
          },
          required: ["agent_id", "changes"]
        },
        handler: &Tools.PACAgent.update_agent/2
      },

      # Memory Tools
      "memory_search" => %{
        description: "Search agent memory",
        input_schema: %{
          type: "object",
          properties: %{
            query: %{type: "string", description: "Search query"},
            agent_id: %{type: "string", description: "Agent ID"},
            limit: %{type: "integer", description: "Max results", default: 10}
          },
          required: ["query", "agent_id"]
        },
        handler: &Tools.Memory.search/2
      },

      "memory_store" => %{
        description: "Store information in agent memory",
        input_schema: %{
          type: "object",
          properties: %{
            content: %{type: "string", description: "Content to store"},
            agent_id: %{type: "string", description: "Agent ID"},
            tags: %{type: "array", items: %{type: "string"}, description: "Memory tags"}
          },
          required: ["content", "agent_id"]
        },
        handler: &Tools.Memory.store/2
      },

      # Zone Tools
      "zone_create" => %{
        description: "Create a new zone",
        input_schema: %{
          type: "object",
          properties: %{
            name: %{type: "string", description: "Zone name"},
            description: %{type: "string", description: "Zone description"},
            size: %{type: "integer", description: "Zone size"}
          },
          required: ["name"]
        },
        handler: &Tools.Zone.create/2
      },

      "zone_list" => %{
        description: "List all zones",
        input_schema: %{
          type: "object",
          properties: %{}
        },
        handler: &Tools.Zone.list/2
      },

      # Communication Tools
      "send_message" => %{
        description: "Send message between agents",
        input_schema: %{
          type: "object",
          properties: %{
            from_agent_id: %{type: "string", description: "Sender agent ID"},
            to_agent_id: %{type: "string", description: "Recipient agent ID"},
            message: %{type: "string", description: "Message content"}
          },
          required: ["from_agent_id", "to_agent_id", "message"]
        },
        handler: &Tools.Communication.send_message/2
      },

      # Observation Tools
      "observe_environment" => %{
        description: "Observe the current environment",
        input_schema: %{
          type: "object",
          properties: %{
            agent_id: %{type: "string", description: "Observer agent ID"},
            range: %{type: "integer", description: "Observation range", default: 10}
          },
          required: ["agent_id"]
        },
        handler: &Tools.Observation.observe_environment/2
      }
    }
  end

  defp execute_tool(tool_spec, arguments, session_id) do
    try do
      # Validate arguments against schema
      case validate_arguments(arguments, tool_spec.input_schema) do
        :ok ->
          # Call the tool handler
          tool_spec.handler.(arguments, session_id)

        {:error, reason} ->
          {:error, {:validation_error, reason}}
      end
    rescue
      error ->
        Logger.error("Tool execution error: #{inspect(error)}")
        {:error, {:execution_error, Exception.message(error)}}
    end
  end

  defp validate_arguments(arguments, schema) do
    # Basic validation - in a real implementation, you'd use a JSON schema validator
    required_fields = Map.get(schema, :required, [])

    missing_fields = required_fields
    |> Enum.filter(fn field -> not Map.has_key?(arguments, field) end)

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end
end
