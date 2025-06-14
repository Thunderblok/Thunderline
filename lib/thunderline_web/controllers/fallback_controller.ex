defmodule ThunderlineWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use ThunderlineWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ThunderlineWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: ThunderlineWeb.ErrorHTML, json: ThunderlineWeb.ErrorJSON)
    |> render(:"404")
  end
  # Handle Ash errors
  def call(conn, {:error, error}) when is_exception(error) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: Exception.message(error)})
  end

  # Handle generic errors
  def call(conn, {:error, error}) when is_binary(error) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: error})
  end

  def call(conn, {:error, error}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: inspect(error)})
  end
end
