defmodule Thunderline.MCP.Tool do
  @moduledoc """
  Behavior for MCP (Model Context Protocol) tools.

  All tools must implement this behavior to be registered
  and used by PAC agents.
  """

  @type params :: map()
  @type result :: {:ok, term()} | {:error, term()}

  @doc """
  Execute the tool with given parameters.

  Parameters will always include:
  - pac_id: The ID of the PAC executing the tool
  - tool_name: The name of the tool being executed
  - execution_id: Unique ID for this execution
  - timestamp: When the tool was called

  Additional parameters depend on the specific tool.
  """
  @callback execute(params) :: result
end
