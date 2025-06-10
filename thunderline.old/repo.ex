defmodule Thunderline.Repo do
  @moduledoc """
  Thunderline Repository - Postgres with pgvector for semantic memory.

  This repo handles all data persistence for:
  - PACs (Personal Autonomous Creations)
  - Mods (PAC modifications/traits)
  - Zones (Virtual spaces/locations)
  - TickLogs (Event timeline records)
  - Memory embeddings via pgvector
  """

  use AshPostgres.Repo, otp_app: :thunderline

  def installed_extensions do
    ["ash-functions", "uuid-ossp", "citext", "vector"]
  end
end
