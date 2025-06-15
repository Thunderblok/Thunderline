# ☤ PAC Zone Resource - Spatial Agent Management System
defmodule Thunderline.PAC.Zone do
  @moduledoc """
  Zone Resource - Spatial containers for PAC agents with real-time coordination. ☤

  Zones represent discrete spatial or conceptual areas where PAC agents exist.
  They provide:
  - Spatial boundaries and constraints
  - Local environment properties
  - Agent interaction contexts
  - Resource availability
  - Real-time event broadcasting via Broadway
  - Presence tracking and session management
  """

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  alias Thunderline.PAC.Agent
  require Logger

  # Permission bitfields inspired by Reticulum
  @permission_spawn_agents 0x01
  @permission_modify_zone 0x02
  @permission_broadcast_events 0x04
  @permission_admin_zone 0x08

  # Zone event types for Broadway processing
  @event_agent_entered "agent_entered"
  @event_agent_left "agent_left"
  @event_resource_changed "resource_changed"
  @event_environment_tick "environment_tick"
  @event_agent_interaction "agent_interaction"

  postgres do
    table "pac_zones"
    repo Thunderline.Repo

    custom_indexes do
      index [:name], unique: true
      index [:properties], using: "gin"
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

    # Permission bitfield for zone operations (Reticulum-inspired)
    attribute :permissions, :integer do
      default @permission_spawn_agents + @permission_broadcast_events
      constraints min: 0, max: 255
    end

    # Server assignment for load balancing (like Reticulum's server assignment)
    attribute :assigned_server, :string do
      constraints max_length: 100
    end

    # Real-time presence tracking
    attribute :active_session_count, :integer do
      default 0
      constraints min: 0
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
        "agent_spawning" => true,
        "max_concurrent_events" => 10
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
      accept [
        :name,
        :description,
        :size,
        :max_agents,
        :properties,
        :rules,
        :permissions,
        :assigned_server
      ]
    end

    update :update do
      accept [
        :description,
        :size,
        :max_agents,
        :properties,
        :rules,
        :permissions,
        :assigned_server
      ]
    end

    # Broadway-powered zone tick with event broadcasting
    update :tick do
      accept []

      change fn changeset, context ->
        zone = changeset.data

        # Update zone properties over time
        current_properties = Ash.Changeset.get_attribute(changeset, :properties) || %{}
        current_rules = Ash.Changeset.get_attribute(changeset, :rules) || %{}

        # Regenerate resources if enabled
        new_properties =
          if Map.get(current_rules, "resource_regeneration", false) do
            resources = Map.get(current_properties, "resources", %{})

            new_resources =
              Map.new(resources, fn {key, value} ->
                # Slow regeneration up to max
                {key, min(100, value + 1)}
              end)

            Map.put(current_properties, "resources", new_resources)
          else
            current_properties
          end

        # Broadcast environment tick event via Broadway
        broadcast_zone_event(
          zone.id,
          @event_environment_tick,
          %{
            properties: new_properties,
            timestamp: DateTime.utc_now()
          },
          context
        )

        Ash.Changeset.change_attribute(changeset, :properties, new_properties)
      end
    end

    # Agent entry/exit actions with real-time broadcasting
    update :agent_entered do
      accept []
      argument :agent_id, :uuid, allow_nil?: false

      change fn changeset, context ->
        zone = changeset.data
        agent_id = Ash.Changeset.get_argument(changeset, :agent_id)

        # Increment session count
        new_count = (zone.active_session_count || 0) + 1

        # Broadcast agent entered event
        broadcast_zone_event(
          zone.id,
          @event_agent_entered,
          %{
            agent_id: agent_id,
            session_count: new_count,
            timestamp: DateTime.utc_now()
          },
          context
        )

        Ash.Changeset.change_attribute(changeset, :active_session_count, new_count)
      end
    end

    update :agent_left do
      accept []
      argument :agent_id, :uuid, allow_nil?: false

      change fn changeset, context ->
        zone = changeset.data
        agent_id = Ash.Changeset.get_argument(changeset, :agent_id)

        # Decrement session count
        new_count = max(0, (zone.active_session_count || 0) - 1)

        # Broadcast agent left event
        broadcast_zone_event(
          zone.id,
          @event_agent_left,
          %{
            agent_id: agent_id,
            session_count: new_count,
            timestamp: DateTime.utc_now()
          },
          context
        )

        Ash.Changeset.change_attribute(changeset, :active_session_count, new_count)
      end
    end

    # Resource consumption with Broadway event processing
    update :consume_resources do
      accept []
      argument :resource_changes, :map, allow_nil?: false

      change fn changeset, context ->
        zone = changeset.data
        resource_changes = Ash.Changeset.get_argument(changeset, :resource_changes)

        current_properties = zone.properties || %{}
        current_resources = Map.get(current_properties, "resources", %{})

        # Apply resource changes
        new_resources =
          Map.merge(current_resources, resource_changes, fn _key, current, change ->
            max(0, min(100, current + change))
          end)

        new_properties = Map.put(current_properties, "resources", new_resources)

        # Broadcast resource change event
        broadcast_zone_event(
          zone.id,
          @event_resource_changed,
          %{
            changes: resource_changes,
            new_resources: new_resources,
            timestamp: DateTime.utc_now()
          },
          context
        )

        Ash.Changeset.change_attribute(changeset, :properties, new_properties)
      end
    end

    read :with_agents do
      prepare build(load: [:agents])
    end

    read :available_for_spawning do
      filter expr(
               fragment("(? ->> 'agent_spawning')::boolean = true", rules) and
                 fragment(
                   "(SELECT COUNT(*) FROM pac_agents WHERE zone_id = ?) < ?",
                   id,
                   max_agents
                 )
             )
    end

    # Find zones by server assignment (load balancing)
    read :by_server do
      argument :server_name, :string, allow_nil?: false
      filter expr(assigned_server == ^arg(:server_name))
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
    domain Thunderline.Domain

    define :create, args: [:name]
    define :get_by_id, action: :read, get_by: [:id]
    define :get_by_name, action: :read, get_by: [:name]
    define :update
    define :tick
    define :agent_entered, args: [:agent_id]
    define :agent_left, args: [:agent_id]
    define :consume_resources, args: [:resource_changes]
    define :with_agents
    define :available_for_spawning
    define :by_server, args: [:server_name]
    define :list_all, action: :read
  end

  # Broadway Event Broadcasting Functions
  # =====================================

  @doc """
  Broadcasts a zone event via Broadway pipeline for concurrent processing.
  This follows Reticulum's pattern of asynchronous event distribution.
  """
  def broadcast_zone_event(zone_id, event_type, payload, context \\ %{}) do
    event_data = %{
      zone_id: zone_id,
      event_type: event_type,
      payload: payload,
      timestamp: DateTime.utc_now(),
      context: context
    }

    # Send to Broadway pipeline for concurrent processing
    case Broadway.push_messages(Thunderline.Zone.EventBroadway, [
           %Broadway.Message{
             data: event_data,
             acknowledger: {__MODULE__, :ack_id, :ack_data}
           }
         ]) do
      :ok ->
        Logger.debug("Broadcasted zone event: #{event_type} for zone #{zone_id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to broadcast zone event: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Broadcasts a zone event to connected Phoenix channels.
  This provides real-time updates to connected clients.
  """
  def broadcast_to_channel(zone_id, event_type, payload) do
    channel_topic = "zone:#{zone_id}"

    Phoenix.PubSub.broadcast(
      Thunderline.PubSub,
      channel_topic,
      {event_type, payload}
    )
  end

  # Permission Helper Functions (Reticulum-inspired)
  # ===============================================

  @doc """
  Checks if a zone has a specific permission using bitfield operations.
  """
  def has_permission?(zone, permission_bit) when is_integer(permission_bit) do
    (zone.permissions &&& permission_bit) == permission_bit
  end

  @doc """
  Grants a permission to a zone using bitfield operations.
  """
  def grant_permission(zone, permission_bit) when is_integer(permission_bit) do
    new_permissions = (zone.permissions || 0) ||| permission_bit
    update(zone, %{permissions: new_permissions})
  end

  @doc """
  Revokes a permission from a zone using bitfield operations.
  """
  def revoke_permission(zone, permission_bit) when is_integer(permission_bit) do
    new_permissions = (zone.permissions || 0) &&& bnot(permission_bit)
    update(zone, %{permissions: new_permissions})
  end

  @doc """
  Checks if an agent can spawn in this zone.
  """
  def can_spawn_agent?(zone) do
    has_permission?(zone, @permission_spawn_agents) and
      Map.get(zone.rules || %{}, "agent_spawning", false) and
      (zone.active_session_count || 0) < zone.max_agents
  end

  @doc """
  Checks if events can be broadcasted in this zone.
  """
  def can_broadcast_events?(zone) do
    has_permission?(zone, @permission_broadcast_events)
  end

  # Server Assignment Functions (Load Balancing)
  # ===========================================

  @doc """
  Assigns a zone to a specific server for load balancing.
  This follows Reticulum's pattern of distributing zones across servers.
  """
  def assign_to_server(zone, server_name) when is_binary(server_name) do
    update(zone, %{assigned_server: server_name})
  end

  @doc """
  Gets all zones assigned to a specific server.
  """
  def get_zones_for_server(server_name) do
    by_server(server_name)
  end

  # Broadway acknowledger (simple passthrough)
  def ack(:ack_id, successful, failed) do
    Logger.debug(
      "Zone events acknowledged: #{length(successful)} successful, #{length(failed)} failed"
    )

    :ok
  end
end
