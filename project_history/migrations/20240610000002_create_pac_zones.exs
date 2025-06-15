defmodule Thunderline.Repo.Migrations.CreatePacZones do
  use Ecto.Migration

  def change do
    create table(:pac_zones, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :name, :string, null: false
      add :description, :text
      add :size, :integer, default: 100, null: false
      add :max_agents, :integer, default: 50, null: false
      add :properties, :map, default: %{}, null: false
      add :rules, :map, default: %{}, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:pac_zones, [:name])
    create index(:pac_zones, :properties, using: :gin)
  end
end
