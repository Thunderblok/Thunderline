defmodule Thunderline.MCP.Tools.Communication do
  @moduledoc """
  Tool for PAC-to-PAC and PAC-to-environment communication.

  Enables PACs to send messages, share information, and
  coordinate with other PACs in their environment.
  """

  @behaviour Thunderline.MCP.Tool

  alias Thunderline.{PAC, Repo}
  alias Thunderline.Communication.MessageBus
  alias Thunderline.Narrative.Engine

  @impl true
  def execute(params) do
    %{
      "pac_id" => pac_id,
      "message" => message,
      "target" => target,
      "type" => communication_type
    } = params

    case communication_type do
      "broadcast" -> broadcast_message(pac_id, message)
      "direct" -> direct_message(pac_id, target, message)
      "zone" -> zone_message(pac_id, message)
      "environment" -> environment_interaction(pac_id, message)
      _ -> {:error, {:invalid_communication_type, communication_type}}
    end
  end

  defp broadcast_message(pac_id, message) do
    with {:ok, pac} <- get_pac(pac_id) do
      # Send message to all PACs in the zone
      broadcast_result = MessageBus.broadcast(%{
        from: pac.name,
        from_id: pac_id,
        message: message,
        type: "broadcast",
        zone_id: pac.zone_id,
        timestamp: DateTime.utc_now()
      })

      result = %{
        type: "broadcast",
        message_sent: message,
        from: pac.name,
        recipients: "all_zone_pacs",
        status: "delivered",
        response: generate_broadcast_response(pac, message)
      }

      {:ok, result}
    end
  end

  defp direct_message(pac_id, target_name, message) do
    with {:ok, pac} <- get_pac(pac_id),
         {:ok, target_pac} <- find_pac_by_name(target_name) do

      # Send direct message
      message_result = MessageBus.direct_message(%{
        from: pac.name,
        from_id: pac_id,
        to: target_pac.name,
        to_id: target_pac.id,
        message: message,
        type: "direct",
        timestamp: DateTime.utc_now()
      })

      result = %{
        type: "direct_message",
        message_sent: message,
        from: pac.name,
        to: target_pac.name,
        status: "delivered",
        response: generate_direct_response(pac, target_pac, message)
      }

      {:ok, result}
    end
  end

  defp zone_message(pac_id, message) do
    with {:ok, pac} <- get_pac(pac_id) do
      # Send message to zone (environment message)
      zone_result = MessageBus.zone_message(%{
        from: pac.name,
        from_id: pac_id,
        message: message,
        zone_id: pac.zone_id,
        type: "zone_announcement",
        timestamp: DateTime.utc_now()
      })

      result = %{
        type: "zone_message",
        message_sent: message,
        from: pac.name,
        zone_response: generate_zone_response(pac, message),
        status: "announced"
      }

      {:ok, result}
    end
  end

  defp environment_interaction(pac_id, message) do
    with {:ok, pac} <- get_pac(pac_id) do
      # Interact with the environment/narrative engine
      interaction_result = Engine.process_environment_interaction(%{
        pac: pac,
        interaction: message,
        timestamp: DateTime.utc_now()
      })

      case interaction_result do
        {:ok, response} ->
          result = %{
            type: "environment_interaction",
            interaction: message,
            from: pac.name,
            environment_response: response.narrative,
            effects: response.effects || [],
            status: "processed"
          }

          {:ok, result}

        {:error, reason} ->
          {:error, {:environment_interaction_failed, reason}}
      end
    end
  end

  # Helper functions

  defp get_pac(pac_id) do
    case Repo.get(PAC, pac_id) do
      nil -> {:error, :pac_not_found}
      pac -> {:ok, pac}
    end
  end

  defp find_pac_by_name(name) do
    case PAC
         |> Ash.Query.filter(name == ^name)
         |> Repo.one() do
      nil -> {:error, :target_pac_not_found}
      pac -> {:ok, pac}
    end
  end

  # Response Generation

  defp generate_broadcast_response(pac, message) do
    # Generate realistic responses from other PACs
    social_level = pac.stats["social"] || 50

    response_likelihood = case social_level do
      level when level > 70 -> 0.8
      level when level > 40 -> 0.5
      _ -> 0.2
    end

    if :rand.uniform() < response_likelihood do
      generate_social_response(pac, message)
    else
      "The message was acknowledged but received no immediate responses."
    end
  end

  defp generate_direct_response(pac, target_pac, message) do
    # Generate response based on target PAC's personality
    target_social = target_pac.stats["social"] || 50
    target_traits = target_pac.traits

    cond do
      target_social > 70 ->
        "#{target_pac.name} responds warmly to your message."

      "analytical" in target_traits ->
        "#{target_pac.name} considers your message thoughtfully before responding."

      "creative" in target_traits ->
        "#{target_pac.name} responds with creative enthusiasm."

      target_social < 30 ->
        "#{target_pac.name} acknowledges your message briefly."

      true ->
        "#{target_pac.name} responds in a friendly manner."
    end
  end

  defp generate_zone_response(pac, message) do
    # Generate environmental/zone response
    responses = [
      "Your words echo through the space, creating ripples of awareness.",
      "The environment seems to absorb and reflect your message.",
      "Other inhabitants of the zone take notice of your announcement.",
      "Your message becomes part of the ongoing narrative of this place."
    ]

    Enum.random(responses)
  end

  defp generate_social_response(pac, message) do
    # Generate realistic social responses
    if String.contains?(String.downcase(message), ["question", "?", "help", "what", "how"]) do
      "Several PACs seem interested in helping answer your question."
    else
      "Your message sparks some interesting conversations among nearby PACs."
    end
  end
end
