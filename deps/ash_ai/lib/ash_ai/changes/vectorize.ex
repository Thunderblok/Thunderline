defmodule AshAi.Changes.Vectorize do
  @moduledoc """
  A change that vectorizes the current values of attributes for a given record.
  Used by the manual vectorization strategy, so you can decide
  later when to run the vectorization action.
  """

  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    {embedding_model, vector_opts} =
      AshAi.Info.vectorize_embedding_model!(changeset.resource)

    name = AshAi.Info.vectorize_full_text_name!(changeset.resource)

    attrs =
      AshAi.Info.vectorize_attributes!(changeset.resource)

    changes =
      case AshAi.Info.vectorize_full_text_text(changeset.resource) do
        {:ok, fun} ->
          attrs ++
            [{:full_text, name, fun}]

        _ ->
          attrs
      end
      |> Enum.flat_map(fn
        {source, dest} ->
          text = Map.get(changeset.data, source)
          [{dest, text}]

        {:full_text, name, fun} ->
          text = fun.(changeset.data)
          [{name, text}]
      end)

    strings = Enum.map(changes, &elem(&1, 1))

    case embedding_model.generate(strings, vector_opts) do
      {:ok, vectors} ->
        changes =
          Enum.zip_with(changes, vectors, fn {k, _}, r ->
            {k, r}
          end)

        Ash.Changeset.change_attributes(changeset, changes)

      {:error, error} ->
        fields = Enum.map(changes, fn {field, _} -> field end)

        Ash.Changeset.add_error(changeset,
          fields: fields,
          message: "An error occurred while generating embeddings: #{inspect(error)}"
        )
    end
  end

  def atomic(changeset, opts, context) do
    {:ok, change(changeset, opts, context)}
  end
end
