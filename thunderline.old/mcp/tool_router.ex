defmodule Thunderline.MCP.ToolRouter do
  @moduledoc """
  Routes and executes MCP tool calls for AI agents.

  Provides:
  - Dynamic tool execution with input validation
  - Error handling and result formatting
  - Tool capability discovery
  - Execution context management
  """

  require Logger

  alias Thunderline.MCP.{ToolRegistry, Tool}

  @type execution_context :: %{
    pac_id: String.t(),
    zone_id: String.t(),
    tick_count: integer(),
    agent_pid: pid(),
    metadata: map()
  }

  @type tool_execution_result ::
    {:ok, term()} |
    {:error, :tool_not_found | :invalid_input | :execution_failed, term()}

  @doc """
  Execute a tool by name with given inputs and context.
  """
  @spec execute_tool(String.t(), map(), execution_context()) :: tool_execution_result()
  def execute_tool(tool_name, inputs, context) do
    Logger.debug("Executing tool: #{tool_name} with inputs: #{inspect(inputs)}")

    with {:ok, tool_spec} <- get_tool_spec(tool_name),
         {:ok, validated_inputs} <- validate_inputs(tool_spec, inputs),
         {:ok, result} <- execute_tool_impl(tool_spec, validated_inputs, context) do

      Logger.debug("Tool #{tool_name} executed successfully")
      {:ok, result}
    else
      {:error, :tool_not_found} ->
        Logger.warning("Tool not found: #{tool_name}")
        {:error, :tool_not_found, "Tool '#{tool_name}' is not registered"}

      {:error, :invalid_input, details} ->
        Logger.warning("Invalid input for tool #{tool_name}: #{inspect(details)}")
        {:error, :invalid_input, details}

      {:error, reason} ->
        Logger.error("Tool execution failed for #{tool_name}: #{inspect(reason)}")
        {:error, :execution_failed, reason}
    end
  end
    @doc """
  List all available tools with their schemas.
  """
  @spec list_tools() :: {:ok, map()}
  def list_tools do
    case ToolRegistry.get_all_tools() do
      {:ok, tools} ->
        tool_schemas =
          tools
          |> Enum.map(fn {name, spec} ->
            {name, %{
              description: Map.get(spec, :description, ""),
              category: Map.get(spec, :category, "general"),
              input_schema: Map.get(spec, :input_schema, %{}),
              output_schema: Map.get(spec, :output_schema, %{})
            }}
          end)
          |> Map.new()

        {:ok, tool_schemas}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get tools by category.
  """
  @spec get_tools_by_category(String.t()) :: {:ok, list()}
  def get_tools_by_category(category) do
    case ToolRegistry.get_tools_by_category(category) do
      {:ok, tools} -> {:ok, tools}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private Functions
    defp get_tool_spec(tool_name) do
    case ToolRegistry.get_tool(tool_name) do
      {:ok, tool_spec} -> {:ok, tool_spec}
      {:error, :not_found} -> {:error, :tool_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_inputs(tool_spec, inputs) do
    schema = Map.get(tool_spec, :input_schema, %{})

    case validate_input_schema(schema, inputs) do
      :ok -> {:ok, inputs}
      {:error, details} -> {:error, :invalid_input, details}
    end
  end

  defp validate_input_schema(schema, inputs) when schema == %{} do
    # No schema means any inputs are valid
    :ok
  end

  defp validate_input_schema(schema, inputs) do
    required_fields = Map.get(schema, :required, [])
    properties = Map.get(schema, :properties, %{})

    # Check required fields
    missing_fields =
      required_fields
      |> Enum.filter(fn field -> not Map.has_key?(inputs, field) end)

    if missing_fields != [] do
      {:error, %{missing_required_fields: missing_fields}}
    else
      # Validate field types if specified
      validate_field_types(properties, inputs)
    end
  end

  defp validate_field_types(properties, inputs) do
    validation_errors =
      inputs
      |> Enum.reduce([], fn {field, value}, errors ->
        case Map.get(properties, field) do
          nil -> errors  # Field not in schema, allow it
          field_spec ->
            case validate_field_type(field_spec, value) do
              :ok -> errors
              {:error, reason} -> [{field, reason} | errors]
            end
        end
      end)

    if validation_errors == [] do
      :ok
    else
      {:error, %{field_validation_errors: validation_errors}}
    end
  end

  defp validate_field_type(field_spec, value) do
    expected_type = Map.get(field_spec, :type, "any")

    case {expected_type, value} do
      {"string", v} when is_binary(v) -> :ok
      {"integer", v} when is_integer(v) -> :ok
      {"number", v} when is_number(v) -> :ok
      {"boolean", v} when is_boolean(v) -> :ok
      {"array", v} when is_list(v) -> :ok
      {"object", v} when is_map(v) -> :ok
      {"any", _} -> :ok
      {expected, _} -> {:error, "Expected #{expected}, got #{inspect(value)}"}
    end
  end

  defp execute_tool_impl(tool_spec, inputs, context) do
    tool_module = Map.get(tool_spec, :module)

    if tool_module && Code.ensure_loaded?(tool_module) do
      try do
        case apply(tool_module, :execute, [inputs, context]) do
          {:ok, result} -> {:ok, result}
          {:error, reason} -> {:error, reason}
          result -> {:ok, result}  # Some tools might return raw results
        end
      rescue
        error ->
          Logger.error("Tool execution exception: #{inspect(error)}")
          {:error, %{exception: inspect(error)}}
      end
    else
      Logger.error("Tool module not found or not loaded: #{inspect(tool_module)}")
      {:error, "Tool implementation not available"}
    end
  end
end
