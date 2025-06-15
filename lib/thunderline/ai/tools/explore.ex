defmodule Thunderline.AI.Tools.Explore do
  @moduledoc """
  Ash AI Tool for agent exploration actions.
  """

  use Ash.Resource,
    domain: Thunderline.Domain

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

    action :explore, :struct do
      description "Explore the environment in a given direction"

      argument :direction, :string, allow_nil?: false # "north", "south", "east", "west", "up", "down"
      argument :intensity, :string, default: "casual" # "casual", "thorough", "cautious"

      run fn input, _context ->
        # Mock implementation - replace with actual exploration logic
        direction = input.arguments.direction
        intensity = input.arguments.intensity

        base_cost = case intensity do
          "casual" -> 5
          "thorough" -> 15
          "cautious" -> 10
          _ -> 10
        end

        {:ok, %{
          discoveries: ["interesting rock formation", "small stream"],
          energy_spent: base_cost,
          interesting_locations: ["#{direction} clearing"],
          result_message: "Explored #{direction} with #{intensity} intensity",
          new_connections: []
        }}
      end
    end
  end

  code_interface do
    domain Thunderline.Domain

    define :explore, args: [:direction, :intensity]
    define :create
  end
end
