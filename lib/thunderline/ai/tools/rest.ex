defmodule Thunderline.AI.Tools.Rest do
  @moduledoc """
  Ash AI Tool for agent rest actions.
  """

  use Ash.Resource,
    domain: Thunderline.Domain

  attributes do
    uuid_primary_key :id
    attribute :duration, :integer, default: 30 # minutes
    attribute :location, :string
    attribute :energy_restored, :integer, default: 0
    attribute :mood_improvement, :integer, default: 0
    timestamps()
  end


  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:duration, :location, :energy_restored, :mood_improvement]
    end

    action :rest, :struct do
      description "Rest and recover energy at a location"

      argument :duration, :integer, default: 30 # minutes
      argument :location_type, :string, default: "current" # "current", "shelter", "comfortable"

      run fn input, _context ->
        # Mock implementation - replace with actual rest logic
        duration = input.arguments.duration
        location_type = input.arguments.location_type

        base_energy = duration * 2
        multiplier = case location_type do
          "shelter" -> 1.5
          "comfortable" -> 2.0
          _ -> 1.0
        end

        energy_restored = round(base_energy * multiplier)

        {:ok, %{
          energy_restored: energy_restored,
          mood_improvement: round(energy_restored * 0.1),
          time_passed: duration,
          result_message: "Rested for #{duration} minutes at #{location_type} location",
          side_effects: []
        }}
      end
    end
  end


  code_interface do
    domain Thunderline.Domain

    define :rest, args: [:duration, :location_type]

    define :create
  end
end
