defmodule Thunderline.World.Zone do
  @moduledoc """
  Zone Resource - 3D grid cells in the PAC Gridworld system.

  Each Zone represents a discrete location in the 3D grid with:
  - Dynamic event state that updates periodically
  - Environmental properties (temperature, entropy, etc.)
  - Event-driven environmental feedback
  - Support for PAC movement and interaction

  Enhanced with Graphmath for 3D spatial operations.
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  # Import Graphmath for 3D operations
  alias Graphmath.Vec3

  postgres do
    table "zones"
    repo Thunderline.Repo

    custom_indexes do
      index [:coords], using: "gin"
      index [:event], using: "gin"
      index [:last_updated_at]
    end
  end

  json_api do
    type "zone"

    routes do
      base "/zones"
      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end
  end

  attributes do
    uuid_primary_key :id

    # 3D grid coordinates - %{x: int, y: int, z: int} per High Command spec
    attribute :coords, :map, allow_nil?: false

    # Dynamic event state per High Command spec
    # Example: %{type: "glitch", description: "Flickering blue flame", hostility: 0.7, rewards: ["insight_shard"], aura: "cold"}
    attribute :event, :map, default: %{}

    # Environmental properties per High Command spec
    attribute :entropy, :float, default: 0.0
    attribute :last_updated_at, :utc_datetime
    # optional: for heat/diffusion
    attribute :temperature, :float, default: 0.0

    timestamps()
  end

  relationships do
    # PACs currently in this zone
    has_many :occupying_agents, Thunderline.PAC.Agent do
      destination_attribute :current_zone_id
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:coords, :event, :entropy, :temperature]

      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :last_updated_at, DateTime.utc_now())
      end
    end

    update :update do
      accept [:event, :entropy, :temperature]

      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :last_updated_at, DateTime.utc_now())
      end
    end

    # Special action for zone tock updates
    update :tock_update do
      accept [:event, :entropy, :temperature]

      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :last_updated_at, DateTime.utc_now())
      end
    end

    # Queries for spatial operations
    read :by_coords do
      argument :coords, :map, allow_nil?: false
      filter expr(coords == ^arg(:coords))
    end

    read :in_range do
      argument :center_coords, :map, allow_nil?: false
      argument :range, :float, allow_nil?: false

      # Note: This will need custom filter logic for 3D distance
      # For now, return all zones (to be refined with Graphmath distance calculation)
      prepare fn query, _context ->
        query
      end
    end

    read :with_event_type do
      argument :event_type, :string, allow_nil?: false
      filter expr(fragment("? ->> 'type' = ?", event, ^arg(:event_type)))
    end

    read :high_entropy do
      argument :threshold, :float, default: 0.7
      filter expr(entropy >= ^arg(:threshold))
    end
  end

  calculations do
    calculate :occupancy_count, :integer do
      calculation fn records, _context ->
        records
        |> Enum.map(fn record ->
          {record, length(record.occupying_agents || [])}
        end)
        |> Map.new()
      end

      load [:occupying_agents]
    end

    calculate :coords_vector, :map do
      calculation fn records, _context ->
        records
        |> Enum.map(fn record ->
          coords = record.coords || %{}

          vector = %{
            x: Map.get(coords, "x", 0),
            y: Map.get(coords, "y", 0),
            z: Map.get(coords, "z", 0)
          }

          {record, vector}
        end)
        |> Map.new()
      end
    end
  end

  validations do
    validate fn changeset, _context ->
      coords = Ash.Changeset.get_attribute(changeset, :coords)

      case coords do
        %{"x" => x, "y" => y, "z" => z} when is_integer(x) and is_integer(y) and is_integer(z) ->
          []

        _ ->
          [{:error, field: :coords, message: "Coords must contain integer x, y, z values"}]
      end
    end

    validate compare(:entropy, greater_than_or_equal_to: 0.0)
  end

  code_interface do
    domain Thunderline.Domain

    define :create

    define :update

    define :tock_update

    define :read

    define :by_coords, args: [:coords]

    define :in_range, args: [:center_coords, :range]

    define :with_event_type, args: [:event_type]

    define :high_entropy, args: [:threshold]
  end
end
