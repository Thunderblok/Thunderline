defmodule Thunderline.AI.Tools.Explore do
  @moduledoc """
  Ash AI Tool for agent exploration actions.
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    extensions: [AshAI.Tool]

  attributes do
    uuid_primary_key :id
    attribute :direction, :string
    attribute :distance, :integer, default: 1
    attribute :discoveries, {:array, :string}, default: []
    attribute :energy_cost, :integer, default: 10
    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:direction, :distance, :discoveries, :energy_cost]
    end
  end

  tool_action :explore do
    description "Explore the environment in a given direction"

    input do
      attribute :direction, :string, allow_nil?: false # "north", "south", "east", "west", "up", "down"
      attribute :intensity, :string, default: "casual" # "casual", "thorough", "cautious"
    end

    output do
      attribute :discoveries, {:array, :string}
      attribute :energy_spent, :integer
      attribute :interesting_locations, {:array, :string}
      attribute :result_message, :string
      attribute :new_connections, {:array, :string}
    end

    execute fn %{direction: direction, intensity: intensity}, _context ->
      # Simulate exploration results based on intensity
      energy_cost = case intensity do
        "casual" -> 10
        "thorough" -> 25
        "cautious" -> 15
        _ -> 10
      end

      # Generate realistic discoveries
      base_discoveries = [
        "interesting terrain features",
        "traces of other agent activity",
        "natural resource deposits",
        "architectural remnants",
        "unusual environmental patterns"
      ]

      discovery_count = case intensity do
        "casual" -> Enum.random(1..2)
        "thorough" -> Enum.random(2..4)
        "cautious" -> Enum.random(1..3)
        _ -> 1
      end

      discoveries = Enum.take_random(base_discoveries, discovery_count)

      interesting_locations = [
        "#{direction}ern clearing",
        "elevated #{direction}ern ridge",
        "#{direction}ern grove"
      ]

      new_connections = case intensity do
        "thorough" -> ["pathway to #{direction}ern sector", "shortcut through #{direction}ern passage"]
        _ -> ["route #{direction}ward"]
      end

      result_message = "Explored #{direction}ward with #{intensity} intensity, discovered #{length(discoveries)} items"

      {:ok, %{
        discoveries: discoveries,
        energy_spent: energy_cost,
        interesting_locations: Enum.take_random(interesting_locations, 1),
        result_message: result_message,
        new_connections: new_connections
      }}
    end
  end

  code_interface do
    domain Thunderline.Domain
    define :explore
  end
end
