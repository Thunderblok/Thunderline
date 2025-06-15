defmodule Thunderline.Repo.Migrations.CreatePacMods do
  use Ecto.Migration

  def change do
    create table(:pac_mods, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :name, :string, null: false
      add :description, :text
      add :mod_type, :string, null: false
      add :config, :map, default: %{}, null: false
      add :effects, :map, default: %{}, null: false
      add :duration, :integer
      add :permanent, :boolean, default: false, null: false
      add :active, :boolean, default: true, null: false
      add :applied_at, :utc_datetime_usec, null: false
      add :pac_agent_id, references(:pac_agents, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:pac_mods, [:pac_agent_id])
    create index(:pac_mods, [:mod_type])
    create index(:pac_mods, :config, using: :gin)
  end
end
