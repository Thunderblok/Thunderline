defmodule Thunderline.Repo.Migrations.AddMovementToPacAgents do
  @moduledoc """
  Migration to add movement and gridworld support to PAC agents.
  """
  use Ecto.Migration

  def change do
    alter table(:pac_agents) do
      # Current zone for movement (different from home zone)
      add :current_zone_id, references(:pac_zones, type: :binary_id, on_delete: :nilify_all)

      # Current 3D grid position
      add :current_coords, :map, default: %{"x" => 0, "y" => 0, "z" => 0}

      # Movement properties
      add :movement_range, :decimal, default: 2.0
      add :last_move_tick, :integer, default: 0
    end

    # Indexes for efficient movement queries
    create index(:pac_agents, [:current_zone_id])
    create index(:pac_agents, [:current_coords], using: "gin")
    create index(:pac_agents, [:last_move_tick])
  end
end
