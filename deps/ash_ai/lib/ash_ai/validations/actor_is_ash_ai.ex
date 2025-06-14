defmodule AshAi.Validations.ActorIsAshAi do
  @moduledoc "A validation that passes if the actor is `%AshAi{}`"

  use Ash.Resource.Validation

  @impl true
  def describe(_), do: "actor is %AshAi{}"

  @impl true
  def validate(_, _, %{actor: %AshAi{}}) do
    :ok
  end

  def validate(_, _, _) do
    {:error, "actor must be Ash AI"}
  end

  @impl true
  def atomic(changeset, opts, context) do
    validate(changeset, opts, context)
  end
end
