defmodule Thunderline.AI.Tools.Rest do
  @moduledoc """
  Ash AI Tool for agent rest/recovery actions.
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    extensions: [AshAI.Tool]

  attributes do
    uuid_primary_key :id
    attribute :duration_minutes, :integer, default: 30
    attribute :energy_recovery, :integer, default: 20
    attribute :result_message, :string
    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:duration_minutes, :energy_recovery, :result_message]
    end
  end

  # Define the actual tool action
  tool_action :rest do
    description "Allow the agent to rest and recover energy"

    input do
      attribute :duration_minutes, :integer, default: 30
      attribute :rest_quality, :string, default: "normal" # "light", "normal", "deep"
    end

    output do
      attribute :energy_gained, :integer
      attribute :mood_improvement, :string
      attribute :time_spent, :integer
      attribute :result_message, :string
    end

    execute fn %{duration_minutes: duration, rest_quality: quality}, _context ->
      # Calculate energy recovery based on duration and quality
      base_recovery = duration / 3  # 1 energy per 3 minutes base
      quality_multiplier = case quality do
        "light" -> 0.7
        "normal" -> 1.0
        "deep" -> 1.5
        _ -> 1.0
      end

      energy_gained = round(base_recovery * quality_multiplier)
      energy_gained = min(energy_gained, 50) # Cap at 50 energy

      mood_improvement = case energy_gained do
        n when n >= 30 -> "significantly refreshed"
        n when n >= 15 -> "moderately refreshed"
        n when n >= 5 -> "slightly refreshed"
        _ -> "barely rested"
      end

      result_message = "Rested for #{duration} minutes with #{quality} quality sleep, gained #{energy_gained} energy"

      {:ok, %{
        energy_gained: energy_gained,
        mood_improvement: mood_improvement,
        time_spent: duration,
        result_message: result_message
      }}
    end
  end

  code_interface do
    domain Thunderline.Domain
    define :rest
  end
end
