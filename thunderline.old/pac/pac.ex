defmodule Thunderline.PAC do
  @moduledoc """
  Personal Autonomous Creation (PAC) - Core entity in the Thunderline substrate.

  A PAC represents an autonomous agent with:
  - Identity and personality traits
  - Evolving state and memory
  - Relationships to other PACs
  - Location within zones
  - Scheduled tick-based evolution

  PACs are the fundamental units of evolution in Thunderline - not just data,
  but reasoning entities powered by Jido agents and MCP tool integration.
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer

  alias Thunderline.PAC.{Mod, Zone}

  postgres do
    table "pacs"
    repo Thunderline.Repo

    custom_indexes do
      index [:name], unique: true
      index [:zone_id]
      index [:state], using: :gin
      index [:traits], using: :gin
    end
  end

  attributes do
    uuid_primary_key :id

    # Identity
    attribute :name, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      constraints max_length: 1000
    end

    # Core stats that influence behavior
    attribute :stats, :map do
      default %{
        "energy" => 100,
        "intelligence" => 50,
        "creativity" => 50,
        "social" => 50,
        "curiosity" => 50
      }
    end

    # Current state and context
    attribute :state, :map do
      default %{
        "mood" => "neutral",
        "activity" => "idle",
        "goals" => [],
        "memories" => []
      }
    end

    # Personality traits and modifiers
    attribute :traits, {:array, :string} do
      default []
    end

    # Last tick information
    attribute :last_tick_at, :utc_datetime
    attribute :tick_count, :integer, default: 0

    # Jido agent configuration
    attribute :agent_config, :map do
      default %{
        "model" => "gpt-4",
        "temperature" => 0.7,
        "max_tokens" => 1000
      }
    end

    timestamps()
  end

  relationships do
    belongs_to :zone, Zone do
      allow_nil? true
    end

    many_to_many :mods, Mod do
      through "pac_mods"
      source_attribute_on_join_resource :pac_id
      destination_attribute_on_join_resource :mod_id
    end

    has_many :tick_logs, Thunderline.Tick.Log do
      source_attribute :id
      destination_attribute :pac_id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :create_with_defaults do
      accept [:name, :description, :zone_id]

      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :stats, default_stats())
      end
    end

    update :update_stats do
      accept [:stats]

      validate attribute_does_not_equal(:stats, %{})
    end

    update :apply_tick do
      accept [:state, :stats, :last_tick_at, :tick_count]

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:last_tick_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:tick_count,
             (Ash.Changeset.get_attribute(changeset, :tick_count) || 0) + 1)
      end
    end

    read :active do
      filter expr(not is_nil(last_tick_at))
    end

    read :in_zone do
      argument :zone_id, :uuid, allow_nil?: false
      filter expr(zone_id == ^arg(:zone_id))
    end
  end

  # Default stats for new PACs
  defp default_stats do
    %{
      "energy" => Enum.random(80..100),
      "intelligence" => Enum.random(40..60),
      "creativity" => Enum.random(40..60),
      "social" => Enum.random(40..60),
      "curiosity" => Enum.random(40..60)
    }
  end
end
