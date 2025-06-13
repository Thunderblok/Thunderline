defmodule Thunderline.Repo.Migrations.CreateMemoryNodes do
  use Ecto.Migration

  def change do
    create table(:memory_nodes, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :content, :text, null: false
      add :summary, :string
      add :embedding, :vector, size: 1536
      add :importance, :decimal, precision: 3, scale: 2, default: 0.5, null: false
      add :tags, {:array, :string}, default: [], null: false
      add :memory_type, :string, default: "episodic", null: false
      add :access_count, :integer, default: 0, null: false
      add :last_accessed_at, :utc_datetime_usec
      add :agent_id, references(:pac_agents, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:memory_nodes, [:agent_id])
    create index(:memory_nodes, :tags, using: :gin)
    create index(:memory_nodes, :embedding, using: "vector")
    create index(:memory_nodes, [:importance])
  end
end
