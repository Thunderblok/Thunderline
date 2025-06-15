defmodule Thunderline.Repo.Migrations.CreateZones do
  @moduledoc """
  Migration to create zones table for the PAC Gridworld system.
  """
  use Ecto.Migration

  def change do
    create table(:zones, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # 3D grid coordinates as JSON
      add :coords, :map, null: false

      # Dynamic event state as JSON
      add :event, :map, default: %{}

      # Environmental properties
      add :entropy, :decimal, default: 0.0
      add :temperature, :decimal, default: 0.0
      add :last_updated_at, :utc_datetime

      # Zone metadata
      add :terrain_type, :string, default: "standard"
      add :accessibility, :decimal, default: 1.0
      add :resource_density, :decimal, default: 0.5

      timestamps()
    end

    # Indexes for efficient querying
    create index(:zones, [:coords], using: "gin")
    create index(:zones, [:event], using: "gin")
    create index(:zones, [:last_updated_at])
    create index(:zones, [:entropy])
    create index(:zones, [:temperature])
    create index(:zones, [:terrain_type])

    # Unique constraint on coordinates to prevent duplicate zones
    create unique_index(:zones, [:coords])
  end
end
