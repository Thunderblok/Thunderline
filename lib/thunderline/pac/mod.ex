# ☤ PAC Mod Resource - Agent Enhancement System
defmodule Thunderline.PAC.Mod do
  @moduledoc """
  Mod Resource - Modifications and enhancements to PAC agents. ☤

  Mods represent:
  - Behavioral modifications ☤
  - Capability enhancements
  - Temporary or permanent changes
  - Tool integrations
  - Memory augmentations
  """
  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  import Ash.Resource.Change

  alias Thunderline.PAC.Agent

  postgres do
    table "pac_mods"
    repo Thunderline.Repo

    custom_indexes do
      index [:pac_agent_id]
      index [:mod_type]
      index [:config], using: "gin"
    end
  end

  json_api do
    type "pac_mod"

    routes do
      base "/pac_mods"
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

    # Type of modification
    attribute :mod_type, :atom do
      allow_nil? false

      constraints one_of: [
                    :behavior,
                    :capability,
                    :memory,
                    :tool,
                    :personality,
                    :stat_boost,
                    :skill
                  ]
    end

    # Configuration and parameters
    attribute :config, :map do
      default %{}
    end

    # Modification effects
    attribute :effects, :map do
      default %{
        "stat_modifiers" => %{},
        "trait_modifiers" => %{},
        "new_capabilities" => [],
        "tool_access" => []
      }
    end

    # Duration and persistence
    attribute :duration, :integer do
      # Duration in ticks, null for permanent
      allow_nil? true
    end

    attribute :permanent, :boolean do
      default false
    end

    # Activation state
    attribute :active, :boolean do
      default true
    end

    attribute :applied_at, :utc_datetime_usec

    timestamps()
  end

  relationships do
    belongs_to :pac_agent, Agent do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :description,
        :mod_type,
        :pac_agent_id,
        :config,
        :effects,
        :duration,
        :permanent
      ]

      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :applied_at, DateTime.utc_now())
      end
    end

    update :update do
      accept [:description, :config, :effects, :active]
    end

    update :apply_to_agent do
      accept []

      change fn changeset, _context ->
        # This will be called when applying the mod's effects to an agent
        # Implementation would depend on the specific mod type and effects
        changeset
      end
    end

    update :deactivate do
      accept []

      change fn changeset, _ ->
        Ash.Changeset.change_attribute(changeset, :active, false)
      end
    end

    update :activate do
      accept []

      change fn changeset, _ ->
        Ash.Changeset.change_attribute(changeset, :active, true)
      end
    end

    read :by_agent do
      argument :pac_agent_id, :uuid, allow_nil?: false
      filter expr(pac_agent_id == ^arg(:pac_agent_id))
    end

    read :by_type do
      argument :mod_type, :atom, allow_nil?: false
      filter expr(mod_type == ^arg(:mod_type))
    end

    read :active do
      filter expr(active == true)
    end

    read :expired do
      filter expr(
               not is_nil(duration) and
                 fragment("? + INTERVAL '1 second' * ? < NOW()", applied_at, duration)
             )
    end
  end

  calculations do
    calculate :is_expired, :boolean do
      calculation fn records, _context ->
        now = DateTime.utc_now()

        records
        |> Enum.map(fn record ->
          expired =
            case record.duration do
              nil ->
                false

              duration ->
                expiry_time = DateTime.add(record.applied_at, duration, :second)
                DateTime.compare(now, expiry_time) == :gt
            end

          {record, expired}
        end)
        |> Map.new()
      end
    end

    calculate :time_remaining, :integer do
      calculation fn records, _context ->
        now = DateTime.utc_now()

        records
        |> Enum.map(fn record ->
          remaining =
            case record.duration do
              nil ->
                nil

              duration ->
                expiry_time = DateTime.add(record.applied_at, duration, :second)
                max(0, DateTime.diff(expiry_time, now, :second))
            end

          {record, remaining}
        end)
        |> Map.new()
      end
    end
  end

  validations do
    validate compare(:duration, greater_than: 0, message: "Duration must be positive") do
      where present(:duration)
    end
  end

  code_interface do
    domain Thunderline.Domain

    define :create, args: [:name, :mod_type, :pac_agent_id]
    define :get_by_id, action: :read, get_by: [:id]
    define :update
    define :apply_to_agent
    define :activate
    define :deactivate
    define :list_by_agent, action: :by_agent, args: [:pac_agent_id]
    define :list_by_type, action: :by_type, args: [:mod_type]
    define :list_active, action: :active
    define :list_expired, action: :expired
  end
end
