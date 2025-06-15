defmodule Thunderline.World.ZoneEvent do
  @moduledoc """
  Zone Event Generator - Creates dynamic events for zones during tock cycles.

  Generates various types of events that can occur in zones:
  - Environmental anomalies (glitches, energy surges, etc.)
  - Resource discoveries or depletions
  - Temporal distortions or memory echoes
  - Hostile or beneficial phenomena
  """

  require Logger
  alias Thunderline.World.Zone

  @event_types [
    "glitch",
    "energy_surge",
    "memory_echo",
    "resource_bloom",
    "temporal_rift",
    "harmonic_resonance",
    "entropy_spike",
    "consciousness_leak",
    "data_storm",
    "quiet_zone"
  ]

  @aura_types [
    "cold",
    "warm",
    "electric",
    "peaceful",
    "chaotic",
    "nostalgic",
    "ominous",
    "vibrant",
    "muted",
    "pulsing"
  ]

  @rewards [
    "insight_shard",
    "energy_crystal",
    "memory_fragment",
    "data_cache",
    "temporal_essence",
    "consciousness_spark",
    "entropy_stabilizer",
    "harmonic_key",
    "void_whisper"
  ]

  @doc """
  Generate a new event for the given zone based on its current state.
  """
  def generate(zone) do
    # Base probability influenced by zone's current entropy and temperature
    entropy = Decimal.to_float(zone.entropy || Decimal.new("0.0"))
    temp = Decimal.to_float(zone.temperature || Decimal.new("0.0"))

    # Higher entropy increases chance of chaotic events
    # Temperature affects event intensity
    event_probability = base_event_probability(entropy, temp)

    if :rand.uniform() < event_probability do
      generate_event(zone, entropy, temp)
    else
      generate_quiet_state(zone)
    end
  end

  defp base_event_probability(entropy, temp) do
    # Base 30% chance, increased by entropy and temperature
    base = 0.3
    # High entropy zones are more active
    entropy_factor = entropy * 0.4
    # Extreme temperatures (hot or cold) increase activity
    temp_factor = abs(temp) * 0.2

    min(0.9, base + entropy_factor + temp_factor)
  end

  defp generate_event(zone, entropy, temp) do
    event_type = Enum.random(@event_types)

    case event_type do
      "glitch" -> generate_glitch_event(entropy, temp)
      "energy_surge" -> generate_energy_event(entropy, temp)
      "memory_echo" -> generate_memory_event(entropy, temp)
      "resource_bloom" -> generate_resource_event(entropy, temp)
      "temporal_rift" -> generate_temporal_event(entropy, temp)
      "harmonic_resonance" -> generate_harmonic_event(entropy, temp)
      "entropy_spike" -> generate_entropy_event(entropy, temp)
      "consciousness_leak" -> generate_consciousness_event(entropy, temp)
      "data_storm" -> generate_data_storm_event(entropy, temp)
      "quiet_zone" -> generate_quiet_state(zone)
    end
  end

  defp generate_glitch_event(entropy, temp) do
    colors = ["blue", "red", "green", "purple", "golden", "silver", "black"]
    phenomena = ["flame", "mist", "sparks", "geometric patterns", "fractals", "shadows"]

    hostility = entropy * 0.6 + :rand.uniform() * 0.4
    intensity = min(1.0, abs(temp) * 0.5 + entropy * 0.3)

    %{
      type: "glitch",
      description: "Flickering #{Enum.random(colors)} #{Enum.random(phenomena)}",
      hostility: Float.round(hostility, 2),
      intensity: Float.round(intensity, 2),
      rewards: maybe_generate_rewards(hostility),
      aura: determine_aura(hostility, temp),
      duration_ticks: :rand.uniform(5) + 1
    }
  end

  defp generate_energy_event(entropy, temp) do
    surge_types = ["electromagnetic", "quantum", "psionic", "thermal", "void"]

    %{
      type: "energy_surge",
      description: "#{Enum.random(surge_types)} energy surge ripples through the area",
      hostility: Float.round(entropy * 0.3, 2),
      intensity: Float.round(abs(temp) * 0.8 + 0.2, 2),
      rewards: maybe_generate_rewards(0.6),
      aura: if(temp > 0, do: "warm", else: "electric"),
      energy_type: Enum.random(surge_types),
      duration_ticks: :rand.uniform(3) + 1
    }
  end

  defp generate_memory_event(entropy, temp) do
    memory_types = ["ancient", "recent", "fragmented", "vivid", "collective", "personal"]

    %{
      type: "memory_echo",
      description: "#{Enum.random(memory_types)} memories drift through the space like whispers",
      hostility: Float.round(entropy * 0.2, 2),
      intensity: Float.round(0.3 + :rand.uniform() * 0.4, 2),
      rewards: ["memory_fragment", "insight_shard"],
      aura: "nostalgic",
      memory_clarity: Float.round(:rand.uniform(), 2),
      duration_ticks: :rand.uniform(4) + 2
    }
  end

  defp generate_resource_event(entropy, temp) do
    resources = ["crystalline formations", "data clusters", "energy pools", "consciousness nodes"]

    %{
      type: "resource_bloom",
      description: "#{Enum.random(resources)} manifest in the area",
      hostility: 0.0,
      intensity: Float.round(0.5 + :rand.uniform() * 0.5, 2),
      rewards: Enum.take_random(@rewards, :rand.uniform(3)),
      aura: "vibrant",
      resource_type: Enum.random(resources),
      duration_ticks: :rand.uniform(8) + 3
    }
  end

  defp generate_temporal_event(entropy, temp) do
    %{
      type: "temporal_rift",
      description: "Time flows differently here, creating ripples in causality",
      hostility: Float.round(entropy * 0.8, 2),
      intensity: Float.round(entropy + abs(temp) * 0.3, 2),
      rewards: maybe_generate_rewards(entropy),
      aura: "chaotic",
      time_dilation: Float.round(0.5 + :rand.uniform() * 1.5, 2),
      duration_ticks: :rand.uniform(6) + 2
    }
  end

  defp generate_harmonic_event(entropy, temp) do
    %{
      type: "harmonic_resonance",
      description:
        "Crystalline harmonics resonate through the space, creating peaceful vibrations",
      hostility: 0.0,
      intensity: Float.round(0.4 + :rand.uniform() * 0.3, 2),
      rewards: ["harmonic_key", "consciousness_spark"],
      aura: "peaceful",
      frequency: Float.round(100 + :rand.uniform() * 900, 1),
      duration_ticks: :rand.uniform(10) + 5
    }
  end

  defp generate_entropy_event(entropy, temp) do
    %{
      type: "entropy_spike",
      description: "Chaos wells up from deep structures, distorting local reality",
      hostility: Float.round(0.8 + entropy * 0.2, 2),
      intensity: Float.round(entropy * 1.2, 2),
      rewards: maybe_generate_rewards(entropy + 0.3),
      aura: "chaotic",
      chaos_level: Float.round(entropy + :rand.uniform() * 0.3, 2),
      duration_ticks: :rand.uniform(4) + 1
    }
  end

  defp generate_consciousness_event(entropy, temp) do
    %{
      type: "consciousness_leak",
      description: "Fragments of awareness seep through dimensional barriers",
      hostility: Float.round(entropy * 0.4, 2),
      intensity: Float.round(0.6 + entropy * 0.2, 2),
      rewards: ["consciousness_spark", "void_whisper", "insight_shard"],
      aura: "ominous",
      awareness_level: Float.round(:rand.uniform(), 2),
      duration_ticks: :rand.uniform(7) + 3
    }
  end

  defp generate_data_storm_event(entropy, temp) do
    %{
      type: "data_storm",
      description: "Torrents of raw information cascade through the area",
      hostility: Float.round(entropy * 0.5, 2),
      intensity: Float.round(0.7 + entropy * 0.3, 2),
      rewards: ["data_cache", "memory_fragment"],
      aura: "electric",
      data_density: Float.round(0.5 + entropy * 0.5, 2),
      duration_ticks: :rand.uniform(5) + 2
    }
  end

  defp generate_quiet_state(zone) do
    %{
      type: "quiet_zone",
      description: "A moment of calm settles over the area",
      hostility: 0.0,
      intensity: 0.1,
      rewards: [],
      aura: "peaceful",
      duration_ticks: :rand.uniform(10) + 5
    }
  end

  defp maybe_generate_rewards(probability) do
    if :rand.uniform() < probability do
      count = min(3, max(1, round(probability * 3)))
      Enum.take_random(@rewards, count)
    else
      []
    end
  end

  defp determine_aura(hostility, temp) do
    cond do
      hostility > 0.7 -> "ominous"
      hostility > 0.4 -> "chaotic"
      temp > 0.5 -> "warm"
      temp < -0.5 -> "cold"
      true -> Enum.random(["peaceful", "muted", "vibrant"])
    end
  end

  @doc """
  Apply an event's effects to a zone's environmental properties.
  """
  def apply_event_effects(zone, event) do
    entropy_change = calculate_entropy_change(event)
    temp_change = calculate_temperature_change(event)

    new_entropy =
      Decimal.add(zone.entropy || Decimal.new("0.0"), Decimal.from_float(entropy_change))

    new_temp =
      Decimal.add(zone.temperature || Decimal.new("0.0"), Decimal.from_float(temp_change))

    # Clamp values to reasonable ranges
    clamped_entropy =
      Decimal.max(Decimal.new("0.0"), Decimal.min(new_entropy, Decimal.new("1.0")))

    clamped_temp = Decimal.max(Decimal.new("-1.0"), Decimal.min(new_temp, Decimal.new("1.0")))

    {clamped_entropy, clamped_temp}
  end

  defp calculate_entropy_change(event) do
    case Map.get(event, "type") do
      "entropy_spike" -> 0.2
      "temporal_rift" -> 0.15
      "glitch" -> 0.1
      "data_storm" -> 0.05
      "harmonic_resonance" -> -0.1
      "quiet_zone" -> -0.05
      _ -> 0.0
    end
  end

  defp calculate_temperature_change(event) do
    case Map.get(event, "type") do
      "energy_surge" -> 0.3
      "entropy_spike" -> 0.1
      "harmonic_resonance" -> -0.2
      "quiet_zone" -> -0.1
      _ -> 0.0
    end
  end
end
