# Ash Framework DSL Syntax Guide

This guide provides an overview of the Ash framework's Domain Specific Language (DSL) syntax, focusing on defining resources and actions. We'll use the `Thunderline.Tick.Log` resource as a primary example of how to structure your Ash resources.

## 1. Defining an Ash Resource

Every Ash resource is an Elixir module that `use Ash.Resource`. This brings in the necessary DSL macros to define your resource's structure and behavior.

Key components of a resource definition:

*   **`use Ash.Resource`**: The entry point for defining an Ash resource.
*   **`domain`**: Specifies the Ash domain this resource belongs to. Domains group related resources and configurations.
*   **`data_layer`**: Defines how the resource interacts with its data store (e.g., PostgreSQL, Ecto).

**Example (`Thunderline.Tick.Log`):**

```elixir
defmodule Thunderline.Tick.Log do
  @moduledoc "Tick Log - Records and tracks the evolution history of PAC Agents."

  use Ash.Resource,
    domain: Thunderline.Domain,
    data_layer: AshPostgres.DataLayer

  # ... rest of the resource definition
end
```

### Postgres Configuration (for `AshPostgres.DataLayer`)

When using `AshPostgres.DataLayer`, you'll typically include a `postgres` block to define table names, repository modules, and custom indexes.

```elixir
  postgres do
    table "tick_logs"      # Specifies the database table name
    repo Thunderline.Repo # Specifies the Ecto Repo module

    # Custom indexes for database performance
    custom_indexes do
      index [:agent_id, :tick_number]
      index [:decision], using: :gin
      # ... other indexes
    end
  end
```

## 2. Defining Attributes

Attributes are the fields of your resource. Ash provides several macros for defining them.

*   **`uuid_primary_key :id`**: A common way to define a UUID primary key named `id`.
*   **`attribute :name, :type, constraints: [...]`**: Defines an attribute with a given name and type.
    *   Common types include `:uuid`, `:string`, `:integer`, `:decimal`, `:map`, `{:array, :map}`, `:boolean`, `:utc_datetime_usec`.
    *   `allow_nil? false` makes the attribute required.
    *   `default` can specify a default value.
    *   `constraints` can enforce rules like `max_length`, `min`, `max`.
*   **`timestamps()`**: A helper that adds `inserted_at` and `updated_at` timestamp attributes.

**Example (`Thunderline.Tick.Log` Attributes):**

```elixir
  attributes do
    uuid_primary_key :id

    attribute :agent_id, :uuid do
      allow_nil? false
    end

    attribute :node_id, :string do
      description "Supervisor node where this tick was executed"
    end

    attribute :tick_number, :integer do
      allow_nil? false
    end

    attribute :decision, :map do
      default %{}
    end

    attribute :errors, {:array, :map} do
      default []
    end

    timestamps() # Adds inserted_at and updated_at
  end
```

## 3. Defining Relationships

Relationships define how resources are connected to each other.

*   **`belongs_to :association_name, OtherResource do ... end`**: Defines a many-to-one or one-to-one relationship.
    *   `source_attribute`: The foreign key on the current resource.
    *   `destination_attribute`: The primary key on the other resource.
*   **`has_many :association_name, OtherResource do ... end`**: Defines a one-to-many relationship.
*   **`has_one :association_name, OtherResource do ... end`**: Defines a strict one-to-one relationship.
*   **`many_to_many :association_name, OtherResource do ... end`**: Defines a many-to-many relationship, often requiring a `through` resource.

**Example (`Thunderline.Tick.Log` Relationship):**

```elixir
  relationships do
    belongs_to :agent, Thunderline.PAC.Agent do
      source_attribute :agent_id
      destination_attribute :id
    end
  end
```

## 4. Defining Actions

Actions define the operations that can be performed on a resource (e.g., creating, reading, updating, deleting).

*   The `actions` block groups all action definitions.
*   `defaults [:read]` can automatically create basic read actions. Other defaults include `[:create, :update, :destroy]`.

### Create Actions

Create actions are used to insert new records.

*   **`create :action_name do ... end`**: Defines a create action.
*   **`accept [...]`**: Specifies a list of attributes that can be provided when creating the resource.

**Example (`Thunderline.Tick.Log` Create Action):**

```elixir
  actions do
    defaults [:read] # Provides default read actions

    create :create_tick_log do
      accept [
        :agent_id, :node_id, :federation_context, :tick_number,
        :tick_duration_ms, :time_since_last_tick, :decision, :reasoning,
        # ... other accepted attributes
        :errors, :broadway_metadata
      ]
    end
    # ... other actions
  end
```

### Read Actions

Read actions are used to query and retrieve resource data. **It is crucial that each `read` action (and other action types) has its own `do ... end` block.**

Common clauses within `read` actions:

*   **`argument :arg_name, :type, constraints: [...]`**: Defines an argument that can be passed to the action.
    *   `allow_nil? false` makes the argument required.
    *   `default` can provide a default value.
*   **`filter expr(...)`**: Defines a filter condition.
    *   `expr(...)` is used for complex expressions.
    *   `^arg(:arg_name)` is used to reference an action argument within an `expr`.
    *   `fragment("SQL_SNIPPET", value)` can be used for database-specific functions or complex conditions.
*   **`sort attribute_name: :asc | :desc`**: Defines the sorting order.
*   **`limit expr(...)`**: Limits the number of results, often using an argument.

**Example (`Thunderline.Tick.Log` Read Actions):**

```elixir
  actions do
    # ... (defaults and create actions) ...

    read :for_agent do # Start of 'for_agent' read action
      do # Each action block must have its own do/end
        argument :agent_id, :uuid, allow_nil?: false
        filter expr(agent_id == ^arg(:agent_id))
      end # End of 'for_agent' read action
    end # This 'end' is for the 'read :for_agent do' block structure itself (optional but good practice for clarity)

    read :for_node do
      do
        argument :node_id, :string, allow_nil?: false
        filter expr(node_id == ^arg(:node_id))
      end
    end

    read :recent do
      do
        argument :limit, :integer, default: 50
        sort inserted_at: :desc
        limit expr(^arg(:limit))
      end
    end

    read :with_errors do
      do
        # Example of using fragment for more complex array checks
        filter expr(fragment("array_length(?, 1) > 0", errors))
      end
    end

    read :successful_ticks do
      do
        # Example of a compound filter
        filter expr(array_length(errors) == 0 and action_success_rate > 0.5)
      end
    end

    read :federation_analytics do
      do
        argument :days_back, :integer, default: 7
        filter expr(inserted_at > ago(^arg(:days_back), "day")) # `ago` is a built-in Ash function
        sort inserted_at: :desc
      end
    end
  end # End of the main 'actions' block
```

**Key Takeaways for Actions:**

*   Each action (e.g., `create :foo do ... end`, `read :bar do ... end`) is a distinct block.
*   For read actions and other actions that take multiple clauses, ensure they are enclosed in their own `do ... end` block, as shown in the `Thunderline.Tick.Log` examples. This ensures correct parsing and execution of the DSL.
*   Proper indentation and clear `end` statements for each block improve readability and help prevent syntax errors.

This guide covers the fundamental aspects of Ash DSL for defining resources and actions. For more advanced features and detailed explanations, refer to the official Ash Framework documentation.
```
