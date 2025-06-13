defmodule Thunderline.Repo.Migrations.CreateTickLogs do
  @moduledoc """
  Migration to create tick_logs table for PAC Agent activity tracking.

  Supports federation with node tracking and cross-node analytics.
  """
  use Ecto.Migration

  def up do
    create table(:tick_logs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # PAC Agent reference
      add :agent_id, references(:pac_agents, type: :uuid, on_delete: :delete_all), null: false

      # Federation metadata
      add :node_id, :string
      add :federation_context, :map, default: %{}

      # Tick identification
      add :tick_number, :integer, null: false

      # Timing data
      add :tick_duration_ms, :integer
      add :time_since_last_tick, :integer

      # Decision and reasoning
      add :decision, :map, default: %{}
      add :reasoning, :text

      # Actions and outcomes
      add :actions_taken, {:array, :map}, default: []
      add :action_success_rate, :decimal, precision: 3, scale: 2

      # State changes
      add :state_changes, :map, default: %{}
      add :stat_changes, :map, default: %{}

      # Context information
      add :zone_context, :map, default: %{}
      add :social_context, :map, default: %{}

      # Memory and narrative
      add :memories_formed, :integer, default: 0
      add :narrative, :text

      # Performance metrics
      add :ai_response_time_ms, :integer
      add :pipeline_stage_times, :map, default: %{}

      # Error tracking
      add :errors, {:array, :map}, default: []

      # Broadway processing metadata
      add :broadway_metadata, :map, default: %{}

      timestamps()
    end

    # Indexes for efficient querying
    create index(:tick_logs, [:agent_id, :tick_number])
    create index(:tick_logs, [:agent_id, :inserted_at])
    create index(:tick_logs, [:node_id, :inserted_at])
    create index(:tick_logs, :decision, using: :gin)
    create index(:tick_logs, :state_changes, using: :gin)
    create index(:tick_logs, :federation_context, using: :gin)
    create index(:tick_logs, :errors, using: :gin)
  end

  def down do
    drop table(:tick_logs)
  end
end
