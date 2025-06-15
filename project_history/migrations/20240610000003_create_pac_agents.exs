defmodule Thunderline.Repo.Migrations.CreatePacAgents do
  use Ecto.Migration

  def change do
    create table(:pac_agents, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :name, :string, null: false
      add :description, :text
      add :stats, :map, default: %{}, null: false
      add :traits, :map, default: %{}, null: false
      add :state, :map, default: %{}, null: false
      add :ai_config, :map, default: %{}, null: false
      add :memory_context, :map, default: %{}, null: false
      add :zone_id, references(:pac_zones, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:pac_agents, [:name])
    create index(:pac_agents, [:zone_id])
    create index(:pac_agents, :state, using: :gin)
    create index(:pac_agents, :traits, using: :gin)
  end
end
