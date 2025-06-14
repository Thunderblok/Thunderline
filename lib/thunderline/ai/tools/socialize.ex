defmodule Thunderline.AI.Tools.Socialize do
  @moduledoc """
  Ash AI Tool for agent social interaction actions.
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    extensions: [AshAI.Tool]

  attributes do
    uuid_primary_key :id
    attribute :interaction_type, :string
    attribute :target_agent, :string
    attribute :conversation_topics, {:array, :string}, default: []
    attribute :outcome, :string
    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:interaction_type, :target_agent, :conversation_topics, :outcome]
    end
  end

  tool_action :socialize do
    description "Interact socially with other agents or entities"

    input do
      attribute :interaction_type, :string, allow_nil?: false # "chat", "collaborate", "trade", "teach", "learn"
      attribute :topic, :string, default: "general" # conversation topic
      attribute :approach, :string, default: "friendly" # "friendly", "formal", "cautious", "enthusiastic"
    end

    output do
      attribute :conversation_summary, :string
      attribute :relationship_change, :string
      attribute :knowledge_gained, {:array, :string}
      attribute :energy_change, :integer
      attribute :result_message, :string
      attribute :future_opportunities, {:array, :string}
    end

    execute fn %{interaction_type: type, topic: topic, approach: approach}, _context ->
      # Simulate social interaction outcomes

      relationship_change = case approach do
        "friendly" -> "slightly improved"
        "formal" -> "remained neutral"
        "cautious" -> "minimal change"
        "enthusiastic" -> "noticeably improved"
        _ -> "unchanged"
      end

      knowledge_gained = case type do
        "chat" -> ["local gossip", "recent events"]
        "collaborate" -> ["collaborative techniques", "shared problem-solving"]
        "trade" -> ["market information", "resource availability"]
        "teach" -> ["teaching satisfaction", "knowledge reinforcement"]
        "learn" -> ["new skills", "different perspectives"]
        _ -> ["general social cues"]
      end

      energy_change = case approach do
        "enthusiastic" -> -5  # costs energy but rewarding
        "friendly" -> 0       # neutral
        "formal" -> -2        # slightly draining
        "cautious" -> -3      # more mentally taxing
        _ -> 0
      end

      conversation_summary = "Had a #{approach} #{type} about #{topic}, leading to #{relationship_change} relations"

      future_opportunities = case type do
        "collaborate" -> ["future project partnerships", "skill sharing sessions"]
        "trade" -> ["business opportunities", "resource exchanges"]
        "teach" -> ["mentoring relationships", "knowledge sharing networks"]
        "learn" -> ["continued learning opportunities", "expert connections"]
        _ -> ["future social interactions"]
      end

      result_message = "#{String.capitalize(type)} interaction completed with #{approach} approach on topic: #{topic}"

      {:ok, %{
        conversation_summary: conversation_summary,
        relationship_change: relationship_change,
        knowledge_gained: knowledge_gained,
        energy_change: energy_change,
        result_message: result_message,
        future_opportunities: Enum.take(future_opportunities, 2)
      }}
    end
  end

  code_interface do
    domain Thunderline.Domain
    define :socialize
  end
end
