defmodule Thunderline.Repo.Migrations.CreateMemoryEdges do
  use Ecto.Migration

  def change do
    create table(:memory_edges, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuid_generate_v4()")
      add :relationship, :string, null: false
      add :strength, :decimal, precision: 3, scale: 2, default: 0.5, null: false
      add :context, :map, default: %{}, null: false
      add :from_node_id, references(:memory_nodes, type: :binary_id, on_delete: :delete_all), null: false
      add :to_node_id, references(:memory_nodes, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:memory_edges, [:from_node_id])
    create index(:memory_edges, [:to_node_id])
    create index(:memory_edges, [:relationship])
    create index(:memory_edges, [:strength])

    # Ensure no self-referential edges
    create constraint(:memory_edges, :no_self_reference,
           check: "from_node_id != to_node_id")
  end
end
