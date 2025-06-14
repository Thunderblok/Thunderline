defmodule AshAi.Checks.ActorIsAshAi do
  @moduledoc "A check that is true when the actor is `%AshAi{}`"
  use Ash.Policy.SimpleCheck

  def describe(_), do: "actor is %AshAi{}"

  def match?(%AshAi{}, _, _), do: true
  def match?(_, _, _), do: false
end
