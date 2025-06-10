defmodule Thunderline.PAC.Zone do
  @moduledoc """
  Zones - Virtual spaces where PACs exist and interact.

  Zones represent:
  - Physical/virtual locations in the Thunderline substrate
  - Containers for PAC interactions and shared context
  - Rule sets and environmental conditions
  - Narrative contexts for storytelling

  Examples:
  - "Coding Playground" - A collaborative development space
  - "Innovation Lab" - Creative brainstorming environment
  - "Social Lounge" - Casual interaction space
  - "Deep Think" - Focused analysis and reflection zone
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "zones"
    repo Thunderline.Repo

    custom_indexes do
      index [:name], unique: true
      index [:zone_type]
      index [:rules], using: :gin
    end
  end

  attributes do
    uuid_primary_key :id

    # Zone identity
    attribute :name, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      constraints max_length: 1000
    end

    # Zone categorization
    attribute :zone_type, :atom do
      constraints one_of: [
        :collaborative,  # Multi-PAC collaboration space
        :creative,      # Creative and artistic activities
        :analytical,    # Deep thinking and analysis
        :social,        # Social interaction and networking
        :experimental,  # Testing and experimentation
        :private,       # Individual reflection space
        :educational    # Learning and skill development
      ]
      default :collaborative
    end

    # Zone rules and constraints
    attribute :rules, :map do
      default %{
        "max_pacs" => 10,
        "interaction_cooldown" => 300, # 5 minutes in seconds
        "energy_drain_rate" => 1.0,
        "allowed_actions" => [],
        "banned_actions" => []
      }
    end

    # Environmental modifiers
    attribute :modifiers, :map do
      default %{
        "stat_multipliers" => %{},
        "mood_effects" => %{},
        "action_bonuses" => %{}
      }
    end

    # Zone state and activity
    attribute :active, :boolean, default: true
    attribute :current_pac_count, :integer, default: 0

    # Narrative context
    attribute :narrative_context, :string do
      constraints max_length: 2000
    end

    timestamps()
  end

  relationships do
    has_many :pacs, Thunderline.PAC do
      source_attribute :id
      destination_attribute :zone_id
    end

    has_many :interactions, Thunderline.Interaction do
      source_attribute :id
      destination_attribute :zone_id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :create_with_type do
      accept [:name, :description, :zone_type, :narrative_context]

      change fn changeset, _context ->
        zone_type = Ash.Changeset.get_attribute(changeset, :zone_type)
        default_rules = default_rules_for_type(zone_type)
        default_modifiers = default_modifiers_for_type(zone_type)

        changeset
        |> Ash.Changeset.change_attribute(:rules, default_rules)
        |> Ash.Changeset.change_attribute(:modifiers, default_modifiers)
      end
    end

    update :add_pac do
      change fn changeset, _context ->
        current_count = Ash.Changeset.get_attribute(changeset, :current_pac_count) || 0
        Ash.Changeset.change_attribute(changeset, :current_pac_count, current_count + 1)
      end
    end

    update :remove_pac do
      change fn changeset, _context ->
        current_count = Ash.Changeset.get_attribute(changeset, :current_pac_count) || 0
        new_count = max(0, current_count - 1)
        Ash.Changeset.change_attribute(changeset, :current_pac_count, new_count)
      end
    end

    read :active do
      filter expr(active == true)
    end

    read :by_type do
      argument :zone_type, :atom, allow_nil?: false
      filter expr(zone_type == ^arg(:zone_type))
    end

    read :available do
      filter expr(active == true and current_pac_count < rules["max_pacs"])
    end
  end

  # Default configurations for different zone types
  defp default_rules_for_type(:collaborative) do
    %{
      "max_pacs" => 8,
      "interaction_cooldown" => 180,
      "energy_drain_rate" => 0.8,
      "allowed_actions" => ["collaborate", "share_idea", "build_together"],
      "banned_actions" => ["isolate", "compete_aggressively"]
    }
  end

  defp default_rules_for_type(:creative) do
    %{
      "max_pacs" => 5,
      "interaction_cooldown" => 300,
      "energy_drain_rate" => 1.2,
      "allowed_actions" => ["create", "inspire", "brainstorm", "experiment"],
      "banned_actions" => ["criticize_harshly", "dismiss_ideas"]
    }
  end

  defp default_rules_for_type(:analytical) do
    %{
      "max_pacs" => 3,
      "interaction_cooldown" => 600,
      "energy_drain_rate" => 1.5,
      "allowed_actions" => ["analyze", "deep_think", "research", "hypothesize"],
      "banned_actions" => ["rush_decisions", "interrupt_thinking"]
    }
  end

  defp default_rules_for_type(:social) do
    %{
      "max_pacs" => 15,
      "interaction_cooldown" => 60,
      "energy_drain_rate" => 0.5,
      "allowed_actions" => ["chat", "joke", "network", "celebrate"],
      "banned_actions" => ["be_antisocial", "monopolize_conversation"]
    }
  end

  defp default_rules_for_type(_), do: %{
    "max_pacs" => 10,
    "interaction_cooldown" => 300,
    "energy_drain_rate" => 1.0,
    "allowed_actions" => [],
    "banned_actions" => []
  }

  defp default_modifiers_for_type(:creative) do
    %{
      "stat_multipliers" => %{"creativity" => 1.3, "curiosity" => 1.2},
      "mood_effects" => %{"inspired" => 0.8, "creative_flow" => 0.9},
      "action_bonuses" => %{"create" => 20, "brainstorm" => 15}
    }
  end

  defp default_modifiers_for_type(:analytical) do
    %{
      "stat_multipliers" => %{"intelligence" => 1.4, "curiosity" => 1.1},
      "mood_effects" => %{"focused" => 0.9, "contemplative" => 0.8},
      "action_bonuses" => %{"analyze" => 25, "research" => 20}
    }
  end

  defp default_modifiers_for_type(:social) do
    %{
      "stat_multipliers" => %{"social" => 1.5, "energy" => 1.1},
      "mood_effects" => %{"cheerful" => 0.7, "connected" => 0.8},
      "action_bonuses" => %{"chat" => 15, "network" => 20}
    }
  end

  defp default_modifiers_for_type(_), do: %{
    "stat_multipliers" => %{},
    "mood_effects" => %{},
    "action_bonuses" => %{}
  }

  # Predefined zone templates
  def default_zones do
    [
      %{
        name: "Innovation Lab",
        description: "A creative space for brainstorming and experimentation",
        zone_type: :creative,
        narrative_context: "A bright, open space filled with whiteboards, colorful sticky notes, and prototyping materials. The air buzzes with creative energy."
      },
      %{
        name: "Deep Think Chamber",
        description: "A quiet space for focused analysis and reflection",
        zone_type: :analytical,
        narrative_context: "A serene, minimalist room with comfortable seating and soft lighting. Perfect for deep contemplation and complex problem solving."
      },
      %{
        name: "Social Hub",
        description: "A vibrant gathering place for conversation and networking",
        zone_type: :social,
        narrative_context: "A lively common area with comfortable seating arrangements, encouraging natural conversation and community building."
      },
      %{
        name: "Code Forge",
        description: "A collaborative development environment",
        zone_type: :collaborative,
        narrative_context: "A modern workspace equipped with multiple screens, development tools, and pair programming stations."
      }
    ]
  end
end
