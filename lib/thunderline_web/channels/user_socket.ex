defmodule ThunderlineWeb.UserSocket do
  @moduledoc """
  UserSocket for Thunderline real-time connections.

  Handles WebSocket connections for zone-based real-time coordination,
  inspired by Mozilla Reticulum's socket architecture.
  """

  use Phoenix.Socket

  # Channel routes
  channel "zone:*", ThunderlineWeb.ZoneChannel

  # Socket params are passed from the client and can be used to verify
  # and authenticate a user. After verification, you can put default assigns
  # into the socket that will be set for all channels, i.e.
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(params, socket, _connect_info) do
    # For now, allow all connections
    # In production, add authentication here
    case validate_connection(params) do
      {:ok, assigns} ->
        socket =
          Enum.reduce(assigns, socket, fn {key, value}, acc ->
            assign(acc, key, value)
          end)

        {:ok, socket}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user
  @impl true
  def id(socket) do
    # Use agent_id if available for socket identification
    case Map.get(socket.assigns, :agent_id) do
      nil -> nil
      agent_id -> "user_socket:#{agent_id}"
    end
  end

  # Private Functions

  defp validate_connection(params) do
    # Basic validation - extend as needed
    assigns = %{}

    # Add any socket-level assigns from params
    assigns =
      case Map.get(params, "agent_id") do
        nil -> assigns
        agent_id -> Map.put(assigns, :agent_id, agent_id)
      end

    {:ok, assigns}
  end
end
