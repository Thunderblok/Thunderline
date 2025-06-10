defmodule Thunderline.Auth do
  @moduledoc """
  Authentication and Authorization for Thunderline.

  Provides JWT-based authentication for:
  - Web interface access
  - API operations
  - MCP tool invocation
  - PAC ownership and control

  Integrates with Ash resources to provide fine-grained access control
  based on user roles and PAC ownership.
  """

  require Logger

  # ========================================
  # JWT Configuration
  # ========================================

  @jwt_secret Application.compile_env(:thunderline, [Thunderline.MCP.Server, :jwt_secret])
  @jwt_algorithm "HS256"
  @default_expiry 24 * 60 * 60  # 24 hours

  # ========================================
  # Token Generation
  # ========================================

  @doc """
  Generate a JWT token for a user.

  ## Examples

      iex> Thunderline.Auth.generate_token("user123")
      {:ok, "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}

      iex> Thunderline.Auth.generate_token("user123", %{role: "admin"})
      {:ok, "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}
  """
  def generate_token(user_id, extra_claims \\ %{}) do
    now = System.system_time(:second)

    claims = %{
      "sub" => user_id,
      "iat" => now,
      "exp" => now + @default_expiry,
      "iss" => "thunderline",
      "aud" => "thunderline-api"
    }
    |> Map.merge(extra_claims)

    case JOSE.JWT.sign(jwk(), claims) do
      {%{alg: :none}, jwt} -> {:error, :signing_failed}
      {_jws, jwt} -> {:ok, jwt}
    end
  rescue
    error ->
      Logger.error("Token generation failed: #{inspect(error)}")
      {:error, :token_generation_failed}
  end

  @doc """
  Verify and decode a JWT token.

  ## Examples

      iex> Thunderline.Auth.verify_token(valid_token)
      {:ok, %{"sub" => "user123", "role" => "user"}}

      iex> Thunderline.Auth.verify_token(invalid_token)
      {:error, :invalid_token}
  """
  def verify_token(token) when is_binary(token) do
    case JOSE.JWT.verify_strict(jwk(), [@jwt_algorithm], token) do
      {true, %JOSE.JWT{fields: claims}, _jws} ->
        case validate_claims(claims) do
          :ok -> {:ok, claims}
          error -> error
        end

      {false, _jwt, _jws} ->
        {:error, :invalid_signature}
    end
  rescue
    error ->
      Logger.debug("Token verification failed: #{inspect(error)}")
      {:error, :invalid_token}
  end

  def verify_token(_), do: {:error, :invalid_token}

  # ========================================
  # Ash Integration
  # ========================================

  @doc """
  Extract actor from request for Ash authorization.

  Used by Ash API to determine the current user context
  for authorization decisions.
  """
  def actor_from_request() do
    fn conn ->
      case get_session_token(conn) || get_bearer_token(conn) do
        nil -> nil
        token ->
          case verify_token(token) do
            {:ok, claims} -> build_actor(claims)
            {:error, _reason} -> nil
          end
      end
    end
  end

  @doc """
  Check if actor has permission for a specific resource operation.

  ## Examples

      iex> Thunderline.Auth.authorize(actor, :read, %Thunderline.PAC{owner_id: "user123"})
      true

      iex> Thunderline.Auth.authorize(actor, :delete, %Thunderline.PAC{owner_id: "other_user"})
      false
  """
  def authorize(actor, action, resource)

  # Admin users can do anything
  def authorize(%{role: "admin"}, _action, _resource), do: true

  # Users can read their own PACs
  def authorize(%{id: user_id}, :read, %{owner_id: owner_id}) when user_id == owner_id, do: true

  # Users can update their own PACs
  def authorize(%{id: user_id}, :update, %{owner_id: owner_id}) when user_id == owner_id, do: true

  # Users can create PACs (ownership will be set to them)
  def authorize(%{id: _user_id}, :create, _resource), do: true

  # Public read access to zones and public PACs
  def authorize(_actor, :read, %{public: true}), do: true

  # Default deny
  def authorize(_actor, _action, _resource), do: false

  # ========================================
  # Token Extraction Helpers
  # ========================================

  defp get_session_token(%Plug.Conn{} = conn) do
    Plug.Conn.get_session(conn, "auth_token")
  end

  defp get_session_token(_), do: nil

  defp get_bearer_token(%Plug.Conn{} = conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end

  defp get_bearer_token(_), do: nil

  # ========================================
  # Internal Helpers
  # ========================================

  defp jwk() do
    JOSE.JWK.from_binary(@jwt_secret)
  end

  defp validate_claims(claims) do
    now = System.system_time(:second)

    cond do
      not Map.has_key?(claims, "exp") ->
        {:error, :missing_expiry}

      claims["exp"] <= now ->
        {:error, :token_expired}

      not Map.has_key?(claims, "sub") ->
        {:error, :missing_subject}

      true ->
        :ok
    end
  end

  defp build_actor(claims) do
    %{
      id: claims["sub"],
      role: Map.get(claims, "role", "user"),
      permissions: Map.get(claims, "permissions", []),
      token_claims: claims
    }
  end

  # ========================================
  # Development Helpers
  # ========================================

  if Mix.env() == :dev do
    @doc """
    Generate a development token for testing.
    Only available in development environment.
    """
    def dev_token(user_id \\ "dev_user", role \\ "admin") do
      {:ok, token} = generate_token(user_id, %{"role" => role})
      token
    end

    @doc """
    Print a development token to console.
    Only available in development environment.
    """
    def print_dev_token() do
      token = dev_token()
      IO.puts("\n" <> String.duplicate("=", 50))
      IO.puts("DEVELOPMENT AUTH TOKEN")
      IO.puts(String.duplicate("=", 50))
      IO.puts("Token: #{token}")
      IO.puts("\nUse in requests:")
      IO.puts("  Authorization: Bearer #{token}")
      IO.puts("\nOr in IEx:")
      IO.puts("  Thunderline.Auth.verify_token(\"#{token}\")")
      IO.puts(String.duplicate("=", 50) <> "\n")
      token
    end
  end
end
