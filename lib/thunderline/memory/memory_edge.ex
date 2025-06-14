# ☤ Memory Edge Resource - Neural Connection System
defmodule Thunderline.Memory.MemoryEdge do
  @moduledoc """
  Memory Edge Resource - Connections between memory nodes. ☤
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  alias Thunderline.Memory.MemoryNode

  postgres do
    table "memory_edges"
    repo Thunderline.Repo

    custom_indexes do
      index [:from_node_id]
      index [:to_node_id]
      index [:relationship]
      index [:strength]
    end
  end

  json_api do
    type "memory_edge"

    routes do
      base "/memory_edges"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end
  end

  attributes do
    uuid_primary_key :id

    # Relationship type
    attribute :relationship, :atom do
      allow_nil? false
      constraints one_of: [
        :causal,         # A caused B
        :temporal,       # A happened before/after B
        :spatial,        # A is near/at B
        :conceptual,     # A is related to B conceptually
        :emotional,      # A triggered emotion about B
        :associative,    # A reminds of B
        :hierarchical,   # A is part of/contains B
        :contradicts     # A contradicts B
      ]
    end

    # Connection strength (0.0 to 1.0)
    attribute :strength, :decimal do
      allow_nil? false
      default Decimal.new("0.5")
      constraints min: Decimal.new("0.0"), max: Decimal.new("1.0")
    end

    # Additional context about the relationship
    attribute :context, :map do
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :from_node, MemoryNode do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :to_node, MemoryNode do
      allow_nil? false
      attribute_writable? true
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:from_node_id, :to_node_id, :relationship, :strength, :context]

      validate fn changeset, _context ->
        from_id = Ash.Changeset.get_attribute(changeset, :from_node_id)
        to_id = Ash.Changeset.get_attribute(changeset, :to_node_id)

        if from_id == to_id do
          {:error, "Cannot create edge from node to itself"}
        else
          :ok
        end
      end
    end

    update :update do
      accept [:relationship, :strength, :context]
    end

    update :strengthen do
      accept []

      change fn changeset, _context ->
        current_strength = Ash.Changeset.get_attribute(changeset, :strength) || Decimal.new("0.5")
        new_strength = Decimal.min(
          Decimal.new("1.0"),
          Decimal.add(current_strength, Decimal.new("0.1"))
        )

        Ash.Changeset.change_attribute(changeset, :strength, new_strength)
      end
    end

    update :weaken do
      accept []

      change fn changeset, _context ->
        current_strength = Ash.Changeset.get_attribute(changeset, :strength) || Decimal.new("0.5")
        new_strength = Decimal.max(
          Decimal.new("0.0"),
          Decimal.sub(current_strength, Decimal.new("0.1"))
        )

        Ash.Changeset.change_attribute(changeset, :strength, new_strength)
      end
    end

    read :by_from_node do
      argument :from_node_id, :uuid, allow_nil?: false
      filter expr(from_node_id == ^arg(:from_node_id))
    end

    read :by_to_node do
      argument :to_node_id, :uuid, allow_nil?: false
      filter expr(to_node_id == ^arg(:to_node_id))
    end

    read :by_relationship do
      argument :relationship, :atom, allow_nil?: false
      filter expr(relationship == ^arg(:relationship))
    end

    read :strong_connections do
      argument :min_strength, :decimal, allow_nil?: false, default: Decimal.new("0.7")
      filter expr(strength >= ^arg(:min_strength))
    end
  end

  validations do
    validate compare(:strength, greater_than_or_equal_to: Decimal.new("0.0"),
                    message: "Strength must be between 0.0 and 1.0")
    validate compare(:strength, less_than_or_equal_to: Decimal.new("1.0"),
                    message: "Strength must be between 0.0 and 1.0")  end
  code_interface do
    domain Thunderline.Domain

    define :create, args: [:from_node_id, :to_node_id, :relationship]
    define :get_by_id, action: :read, get_by: [:id]
    define :update
    define :strengthen
    define :weaken
    define :list_by_from_node, action: :by_from_node, args: [:from_node_id]
    define :list_by_to_node, action: :by_to_node, args: [:to_node_id]
    define :list_by_relationship, action: :by_relationship, args: [:relationship]
    define :list_strong_connections, action: :strong_connections, args: [:min_strength]
  end
end
