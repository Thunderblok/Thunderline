defmodule Thunderline.MCP.Session do
  @moduledoc """
  MCP Session management for tracking client connections and state.
  """

  defstruct [:id, :socket, :created_at, :last_activity, :metadata]

  def new(id, socket) do
    %__MODULE__{
      id: id,
      socket: socket,
      created_at: DateTime.utc_now(),
      last_activity: DateTime.utc_now(),
      metadata: %{}
    }
  end

  def get_socket(session) do
    session.socket
  end

  def send_notification(session, notification) do
    message = %{
      method: "notifications/message",
      params: notification
    }

    data = Jason.encode!(message) <> "\n"
    :gen_tcp.send(session.socket, data)
  end

  def update_activity(session) do
    %{session | last_activity: DateTime.utc_now()}
  end

  def set_metadata(session, key, value) do
    new_metadata = Map.put(session.metadata, key, value)
    %{session | metadata: new_metadata}
  end

  def get_metadata(session, key, default \\ nil) do
    Map.get(session.metadata, key, default)
  end
end
