# ☤ Memory Node Resource - Thunderline Neural Memory System
defmodule Thunderline.Memory.MemoryNode do
  @moduledoc """
  Memory Node Resource - Individual memory units in the agent memory system. ☤
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  alias Thunderline.PAC.Agent
  alias Thunderline.Memory.MemoryEdge

  postgres do
    table "memory_nodes"
    repo Thunderline.Repo

    custom_indexes do
      index [:agent_id]
      index [:tags], using: "gin"
      index [:embedding], using: "vector"
      index [:importance]
    end
  end

  json_api do
    type "memory_node"

    routes do
      base "/memory_nodes"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      constraints max_length: 10000
    end

    attribute :summary, :string do
      constraints max_length: 500
    end

    # Vector embedding for similarity search
    attribute :embedding, :vector do
      allow_nil? true
      # OpenAI text-embedding-3-small dimensions
      constraints dimensions: 1536
    end

    # Importance score (0.0 to 1.0)
    attribute :importance, :decimal do
      default Decimal.new("0.5")
      constraints min: Decimal.new("0.0"), max: Decimal.new("1.0")
    end

    # Tags for categorization
    attribute :tags, {:array, :string} do
      default []
    end

    # Memory type
    attribute :memory_type, :atom do
      allow_nil? false
      default :episodic
      constraints one_of: [:episodic, :semantic, :procedural, :emotional]
    end

    # Access statistics
    attribute :access_count, :integer do
      default 0
    end

    attribute :last_accessed_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :agent, Agent do
      allow_nil? false
      attribute_writable? true
    end

    has_many :outgoing_edges, MemoryEdge do
      destination_attribute :from_node_id
    end

    has_many :incoming_edges, MemoryEdge do
      destination_attribute :to_node_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:content, :summary, :agent_id, :importance, :tags, :memory_type]

      change fn changeset, _context ->
        # Generate embedding for the content
        content = Ash.Changeset.get_attribute(changeset, :content)

        case generate_embedding(content) do
          {:ok, embedding} ->
            Ash.Changeset.change_attribute(changeset, :embedding, embedding)

          {:error, _} ->
            # Continue without embedding
            changeset
        end
      end
    end

    update :update do
      accept [:content, :summary, :importance, :tags, :memory_type]

      change fn changeset, _context ->
        # Re-generate embedding if content changed
        if Ash.Changeset.changing_attribute?(changeset, :content) do
          content = Ash.Changeset.get_attribute(changeset, :content)

          case generate_embedding(content) do
            {:ok, embedding} ->
              Ash.Changeset.change_attribute(changeset, :embedding, embedding)

            {:error, _} ->
              changeset
          end
        else
          changeset
        end
      end
    end

    update :access do
      accept []

      change fn changeset, _context ->
        current_count = Ash.Changeset.get_attribute(changeset, :access_count) || 0

        changeset
        |> Ash.Changeset.change_attribute(:access_count, current_count + 1)
        |> Ash.Changeset.change_attribute(:last_accessed_at, DateTime.utc_now())
      end
    end

    read :by_agent do
      argument :agent_id, :uuid, allow_nil?: false
      filter expr(agent_id == ^arg(:agent_id))
    end

    read :by_tags do
      argument :tags, {:array, :string}, allow_nil?: false
      filter expr(fragment("? && ?", tags, ^arg(:tags)))
    end

    read :by_importance do
      argument :min_importance, :decimal, allow_nil?: false
      filter expr(importance >= ^arg(:min_importance))
    end

    read :similar_to do
      argument :embedding, :vector, allow_nil?: false
      argument :limit, :integer, allow_nil?: false, default: 10
      argument :threshold, :decimal, allow_nil?: false, default: Decimal.new("0.7")

      filter expr(fragment("? <=> ? < ?", embedding, ^arg(:embedding), ^arg(:threshold)))
    end
  end

  calculations do
    calculate :connected_nodes, :integer do
      calculation fn records, _context ->
        records
        |> Enum.map(fn record ->
          outgoing_count = length(record.outgoing_edges || [])
          incoming_count = length(record.incoming_edges || [])
          {record, outgoing_count + incoming_count}
        end)
        |> Map.new()
      end

      load [:outgoing_edges, :incoming_edges]
    end
  end

  validations do
    validate compare(:importance,
               greater_than_or_equal_to: Decimal.new("0.0"),
               message: "Importance must be between 0.0 and 1.0"
             )

    validate compare(:importance,
               less_than_or_equal_to: Decimal.new("1.0"),
               message: "Importance must be between 0.0 and 1.0"
             )
  end

  code_interface do
    domain Thunderline.Domain

    define :create, args: [:content, :agent_id]
    define :get_by_id, action: :read, get_by: [:id]
    define :update
    define :access
    define :list_by_agent, action: :by_agent, args: [:agent_id]
    define :list_by_tags, action: :by_tags, args: [:tags]
    define :list_by_importance, action: :by_importance, args: [:min_importance]
    define :find_similar, action: :similar_to, args: [:embedding, :limit, :threshold]
    define :destroy, action: :destroy
  end

  # Private helper functions

  defp generate_embedding(content) do
    # This would integrate with OpenAI or another embedding service
    # For now, return a placeholder
    {:ok, List.duplicate(0.0, 1536)}
  end
end
