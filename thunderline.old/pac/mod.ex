defmodule Thunderline.PAC.Mod do
  @moduledoc """
  Modifications (Mods) - Traits and abilities that can be applied to PACs.

  Mods represent:
  - Personality modifiers (e.g., "curious", "analytical", "social")
  - Skill enhancements (e.g., "code_generation", "creative_writing")
  - Behavioral patterns (e.g., "night_owl", "early_riser")
  - Tool integrations (e.g., "web_search", "file_operations")

  Mods are composable and can be dynamically applied/removed from PACs,
  allowing for evolution and adaptation over time.
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "mods"
    repo Thunderline.Repo

    custom_indexes do
      index [:name], unique: true
      index [:category]
      index [:effects], using: :gin
    end
  end

  attributes do
    uuid_primary_key :id

    # Mod identity
    attribute :name, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      constraints max_length: 500
    end

    # Mod categorization
    attribute :category, :atom do
      constraints one_of: [
        :personality,    # Personality modifiers
        :skill,         # Skill enhancements
        :behavior,      # Behavioral patterns
        :tool,          # Tool integrations
        :memory,        # Memory enhancements
        :social,        # Social capabilities
        :creative       # Creative abilities
      ]
      default :personality
    end

    # Stat effects when applied
    attribute :effects, :map do
      default %{
        "stat_modifiers" => %{},
        "new_actions" => [],
        "trait_additions" => [],
        "behavior_changes" => %{}
      }
    end

    # Requirements for application
    attribute :requirements, :map do
      default %{
        "min_stats" => %{},
        "required_traits" => [],
        "conflicting_mods" => []
      }
    end

    # Rarity and availability
    attribute :rarity, :atom do
      constraints one_of: [:common, :uncommon, :rare, :legendary]
      default :common
    end

    attribute :active, :boolean, default: true

    timestamps()
  end

  relationships do
    many_to_many :pacs, Thunderline.PAC do
      through "pac_mods"
      source_attribute_on_join_resource :mod_id
      destination_attribute_on_join_resource :pac_id
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    create :create_personality_mod do
      accept [:name, :description, :effects, :requirements]

      change set_attribute(:category, :personality)
    end

    create :create_skill_mod do
      accept [:name, :description, :effects, :requirements]

      change set_attribute(:category, :skill)
    end

    read :by_category do
      argument :category, :atom, allow_nil?: false
      filter expr(category == ^arg(:category))
    end

    read :compatible_with_pac do
      argument :pac, Thunderline.PAC, allow_nil?: false

      # TODO: Implement compatibility checking based on requirements
    end

    read :active do
      filter expr(active == true)
    end
  end

  # Predefined mod templates
  def personality_mods do
    [
      %{
        name: "Curious Explorer",
        description: "Increases curiosity and drives exploration behavior",
        effects: %{
          "stat_modifiers" => %{"curiosity" => 20},
          "trait_additions" => ["explorer", "question_asker"],
          "behavior_changes" => %{"exploration_frequency" => 1.5}
        }
      },
      %{
        name: "Social Butterfly",
        description: "Enhances social interactions and relationship building",
        effects: %{
          "stat_modifiers" => %{"social" => 25},
          "trait_additions" => ["friendly", "networker"],
          "new_actions" => ["initiate_conversation", "organize_event"]
        }
      },
      %{
        name: "Deep Thinker",
        description: "Increases analytical capabilities and reflection time",
        effects: %{
          "stat_modifiers" => %{"intelligence" => 20},
          "trait_additions" => ["analytical", "thoughtful"],
          "behavior_changes" => %{"thinking_time" => 2.0}
        }
      }
    ]
  end

  def skill_mods do
    [
      %{
        name: "Code Generator",
        description: "Enables advanced code generation and programming assistance",
        category: :skill,
        effects: %{
          "new_actions" => ["generate_code", "debug_code", "explain_code"],
          "trait_additions" => ["programmer", "technical"]
        },
        requirements: %{
          "min_stats" => %{"intelligence" => 60}
        }
      },
      %{
        name: "Creative Writer",
        description: "Enhances creative writing and storytelling abilities",
        category: :skill,
        effects: %{
          "stat_modifiers" => %{"creativity" => 30},
          "new_actions" => ["write_story", "create_poem", "brainstorm"],
          "trait_additions" => ["creative", "storyteller"]
        }
      }
    ]
  end
end
