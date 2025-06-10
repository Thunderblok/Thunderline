defmodule Thunderline.Repo do
  @moduledoc """
  Thunderline database repository.
  """

  use Ecto.Repo,
    otp_app: :thunderline,
    adapter: Ecto.Adapters.Postgres

  def installed_extensions do
    ["uuid-ossp", "citext", "vector"]
  end
end
