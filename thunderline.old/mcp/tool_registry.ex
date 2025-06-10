defmodule Thunderline.MCP.ToolRegistry do
  @moduledoc """
  Registry for managing MCP tools available to AI agents.

  Provides:
  - Tool registration and discovery
  - Schema validation
  - Tool categorization and search
  - Dynamic tool loading/unloading
  """

  use GenServer
  require Logger

  defstruct [:tools, :categories]

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

  def get_tool(tool_name) do
    GenServer.call(__MODULE__, {:get_tool, tool_name})
  end

  def get_all_tools do
    GenServer.call(__MODULE__, :get_all_tools)
  end

  def get_tools_by_category(category) do
    GenServer.call(__MODULE__, {:get_tools_by_category, category})
  end

  def list_categories do
    GenServer.call(__MODULE__, :list_categories)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      tools: %{},
      categories: MapSet.new()
    }

    # Register built-in tools
    {:ok, state, {:continue, :register_builtin_tools}}
  end

  @impl true
  def handle_continue(:register_builtin_tools, state) do
    builtin_tools = [
      %{
        name: "memory_search",
        description: "Search semantic memory for relevant information",
        category: "memory",
        module: Thunderline.MCP.Tools.MemorySearch,
        input_schema: %{
          type: "object",
          required: ["query"],
          properties: %{
            "query" => %{type: "string", description: "Search query"},
            "limit" => %{type: "integer", description: "Max results", default: 10}
          }
        }
      },
      %{
        name: "communicate",
        description: "Send messages to other PACs or environment",
        category: "communication",
        module: Thunderline.MCP.Tools.Communication,
        input_schema: %{
          type: "object",
          required: ["target", "message"],
          properties: %{
            "target" => %{type: "string", description: "Target PAC ID or 'environment'"},
            "message" => %{type: "string", description: "Message content"},
            "channel" => %{type: "string", description: "Communication channel", default: "default"}
          }
        }
      },
      %{
        name: "observe",
        description: "Observe environment and context",
        category: "perception",
        module: Thunderline.MCP.Tools.Observation,
        input_schema: %{
          type: "object",
          properties: %{
            "scope" => %{type: "string", description: "Observation scope", default: "local"},
            "details" => %{type: "boolean", description: "Include detailed info", default: false}
          }
        }
      }
    ]

    new_state =
      builtin_tools
      |> Enum.reduce(state, fn tool_spec, acc_state ->
        case register_tool_impl(acc_state, tool_spec) do
          {:ok, updated_state} ->
            Logger.debug("Registered builtin tool: #{tool_spec.name}")
            updated_state
          {:error, reason} ->
            Logger.warning("Failed to register builtin tool #{tool_spec.name}: #{inspect(reason)}")
            acc_state
        end
      end)

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:register_tool, tool_spec}, _from, state) do
    case register_tool_impl(state, tool_spec) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:unregister_tool, tool_name}, _from, state) do
    case unregister_tool_impl(state, tool_name) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_tool, tool_name}, _from, state) do
    result = get_tool_impl(state, tool_name)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_all_tools, _from, state) do
    {:reply, {:ok, state.tools}, state}
  end

  @impl true
  def handle_call({:get_tools_by_category, category}, _from, state) do
    tools = get_tools_by_category_impl(state, category)
    {:reply, {:ok, tools}, state}
  end

  @impl true
  def handle_call(:list_categories, _from, state) do
    categories = MapSet.to_list(state.categories)
    {:reply, {:ok, categories}, state}
  end

  # Private Implementation Functions

  defp register_tool_impl(state, tool_spec) do
    case validate_tool_spec(tool_spec) do
      {:ok, validated_tool} ->
        new_tools = Map.put(state.tools, validated_tool.name, validated_tool)
        category = Map.get(validated_tool, :category, "general")
        new_categories = MapSet.put(state.categories, category)

        new_state = %{state |
          tools: new_tools,
          categories: new_categories
        }

        {:ok, new_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp unregister_tool_impl(state, tool_name) do
    if Map.has_key?(state.tools, tool_name) do
      new_tools = Map.delete(state.tools, tool_name)
      new_state = %{state | tools: new_tools}
      {:ok, new_state}
    else
      {:error, :not_found}
    end
  end

  defp get_tool_impl(state, tool_name) do
    case Map.get(state.tools, tool_name) do
      nil -> {:error, :not_found}
      tool -> {:ok, tool}
    end
  end

  defp get_tools_by_category_impl(state, category) do
    state.tools
    |> Map.values()
    |> Enum.filter(&(Map.get(&1, :category, "general") == category))
  end

  defp validate_tool_spec(tool_spec) do
    required_fields = [:name, :description, :input_schema]

    missing_fields =
      required_fields
      |> Enum.reject(&Map.has_key?(tool_spec, &1))

    if Enum.empty?(missing_fields) do
      # Ensure tool_spec is a map with atom keys
      normalized_spec =
        tool_spec
        |> Enum.into(%{})
        |> Map.put_new(:category, "general")
        |> Map.put_new(:output_schema, %{})

      {:ok, normalized_spec}
    else
      {:error, {:missing_fields, missing_fields}}
    end
  end
end
