# ☤ PAC Agent Resource - Autonomous Entity System
defmodule Thunderline.PAC.Agent do
  @moduledoc """
  PAC Agent Resource - Autonomous entities in the Thunderline substrate. ☤

  A PAC Agent represents an autonomous entity with:
  - Identity and personality traits
  - Evolving state and memory
  - Relationships to other PACs
  - Location within zones
  - Scheduled tick-based evolution

  PAC Agents are the fundamental units of evolution in Thunderline - not just data,
  but reasoning entities powered by Jido agents and MCP tool integration.
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  alias Thunderline.PAC.{Zone, Mod}

  postgres do
    table "pac_agents"
    repo Thunderline.Repo

    custom_indexes do
      index [:name], unique: true
      index [:zone_id]
      index [:state], using: "gin"
      index [:traits], using: "gin"
    end
  end

  json_api do
    type "pac_agent"

    routes do
      base "/pac_agents"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
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
        "creativity" => 50,
        "focus" => 50,
        "social" => 50,
        "exploration" => 50
      }
    end

    # Personality traits - influence decision making
    attribute :traits, :map do
      default %{
        "openness" => 0.5,
        "conscientiousness" => 0.5,
        "extraversion" => 0.5,
        "agreeableness" => 0.5,
        "neuroticism" => 0.5
      }
    end

    # Dynamic state that changes over time
    attribute :state, :map do
      default %{
        "mood" => "neutral",
        "activity" => "idle",
        "goals" => [],
        "current_focus" => nil
      }
    end

    # AI model configuration
    attribute :ai_config, :map do
      default %{
        "model" => "gpt-4-turbo-preview",
        "temperature" => 0.7,
        "max_tokens" => 1000,
        "system_prompt" => nil
      }
    end

    # Memory and context
    attribute :memory_context, :map do
      default %{
        "short_term" => [],
        "long_term_ids" => [],
        "active_memories" => 10
      }
    end

    timestamps()
  end

  relationships do
    belongs_to :zone, Zone do
      allow_nil? false
    end

    has_many :mods, Mod do
      destination_attribute :pac_agent_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :zone_id, :stats, :traits, :ai_config]

      change fn changeset, _ ->
        # Initialize default state and memory context
        changeset
        |> Ash.Changeset.change_attribute(:state, %{
          "mood" => "neutral",
          "activity" => "initializing",
          "goals" => [],
          "current_focus" => "understanding_environment"
        })
        |> Ash.Changeset.change_attribute(:memory_context, %{
          "short_term" => [],
          "long_term_ids" => [],
          "active_memories" => 10
        })
      end
    end

    update :update do
      accept [:description, :stats, :traits, :state, :ai_config, :memory_context]
    end

    update :tick do
      accept []

      change fn changeset, context ->
        # This will be called by the tick system
        # Update energy, mood, and other dynamic properties
        current_stats = Ash.Changeset.get_attribute(changeset, :stats) || %{}
        current_state = Ash.Changeset.get_attribute(changeset, :state) || %{}

        # Energy recovery and decay logic
        new_energy = min(100, Map.get(current_stats, "energy", 50) + 5)
        new_stats = Map.put(current_stats, "energy", new_energy)

        # Update activity based on energy and mood
        new_activity = cond do
          new_energy > 80 -> "active"
          new_energy > 40 -> "moderate"
          true -> "resting"
        end

        new_state = Map.put(current_state, "activity", new_activity)

        changeset
        |> Ash.Changeset.change_attribute(:stats, new_stats)
        |> Ash.Changeset.change_attribute(:state, new_state)
      end
    end

    read :by_zone do
      argument :zone_id, :uuid, allow_nil?: false
      filter expr(zone_id == ^arg(:zone_id))
    end

    read :active do
      filter expr(fragment("?->>'activity' != 'inactive'", state))
    end
  end

  validations do
    validate compare(:name, greater_than: 0, message: "Name cannot be empty") do
      where changing(:name)
    end  end
  code_interface do
    domain Thunderline.Domain

    define :create, args: [:name, :zone_id]
    define :get_by_id, action: :read, get_by: [:id]
    define :get_by_name, action: :read, get_by: [:name]
    define :update
    define :tick
    define :list_by_zone, action: :by_zone, args: [:zone_id]
    define :list_active, action: :active
  end
end
