defmodule Thunderline.PAC.Zone do
  @moduledoc """
  Zone Resource - Spatial containers for PAC agents.

  Zones represent discrete spatial or conceptual areas where PAC agents exist.
  They provide:
  - Spatial boundaries and constraints
  - Local environment properties
  - Agent interaction contexts
  - Resource availability
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  alias Thunderline.PAC.Agent

  postgres do
    table "pac_zones"
    repo Thunderline.Repo

    custom_indexes do
      index [:name], unique: true
      index [:properties], using: :gin
    end
  end

  json_api do
    type "pac_zone"

    routes do
      base "/pac_zones"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 100
    end

    attribute :description, :string do
      constraints max_length: 1000
    end

    # Zone size and capacity
    attribute :size, :integer do
      default 100
      constraints min: 1, max: 1000
    end

    attribute :max_agents, :integer do
      default 50
      constraints min: 1, max: 200
    end

    # Environment properties that affect agents
    attribute :properties, :map do
      default %{
        "temperature" => 20.0,
        "humidity" => 0.5,
        "light_level" => 0.8,
        "noise_level" => 0.3,
        "resources" => %{
          "food" => 100,
          "materials" => 100,
          "energy" => 100
        }
      }
    end

    # Zone-specific rules and constraints
    attribute :rules, :map do
      default %{
        "movement_cost" => 1,
        "interaction_range" => 10,
        "resource_regeneration" => true,
        "agent_spawning" => true
      }
    end

    timestamps()
  end

  relationships do
    has_many :agents, Agent do
      destination_attribute :zone_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :description, :size, :max_agents, :properties, :rules]
    end

    update :update do
      accept [:description, :size, :max_agents, :properties, :rules]
    end

    update :tick do
      accept []

      change fn changeset, _context ->
        # Update zone properties over time
        current_properties = Ash.Changeset.get_attribute(changeset, :properties) || %{}
        current_rules = Ash.Changeset.get_attribute(changeset, :rules) || %{}

        # Regenerate resources if enabled
        new_properties = if Map.get(current_rules, "resource_regeneration", false) do
          resources = Map.get(current_properties, "resources", %{})

          new_resources = Map.new(resources, fn {key, value} ->
            # Slow regeneration up to max
            {key, min(100, value + 1)}
          end)

          Map.put(current_properties, "resources", new_resources)
        else
          current_properties
        end

        Ash.Changeset.change_attribute(changeset, :properties, new_properties)
      end
    end

    read :with_agents do
      prepare build(load: [:agents])
    end

    read :available_for_spawning do
      filter expr(
        fragment("(? ->> 'agent_spawning')::boolean = true", rules) and
        fragment("(SELECT COUNT(*) FROM pac_agents WHERE zone_id = ?) < ?", id, max_agents)
      )
    end
  end

  calculations do
    calculate :agent_count, :integer do
      calculation fn records, _context ->
        records
        |> Enum.map(fn record ->
          {record, length(record.agents || [])}
        end)
        |> Map.new()
      end

      load [:agents]
    end

    calculate :available_space, :integer do
      calculation fn records, _context ->
        records
        |> Enum.map(fn record ->
          agent_count = length(record.agents || [])
          {record, record.max_agents - agent_count}
        end)
        |> Map.new()
      end

      load [:agents]
    end
  end

  validations do
    validate compare(:size, greater_than: 0, message: "Size must be positive")
    validate compare(:max_agents, greater_than: 0, message: "Max agents must be positive")
  end

  code_interface do
    define_for Thunderline.Domain
    define :create, args: [:name]
    define :get_by_id, action: :read, get_by: [:id]
    define :get_by_name, action: :read, get_by: [:name]
    define :update
    define :tick
    define :with_agents
    define :available_for_spawning
  end
end
