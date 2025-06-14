defmodule AshAi.Transformers.Vectorize do
  @moduledoc false
  use Spark.Dsl.Transformer

  import Spark.Dsl.Builder
  import Ash.Resource.Builder

  def after?(_), do: true

  def transform(dsl) do
    attrs =
      dsl
      |> AshAi.Info.vectorize_attributes!()

    uses_full_text = match?({:ok, _}, AshAi.Info.vectorize_full_text_text(dsl))

    if Enum.empty?(attrs) && !uses_full_text do
      {:ok, dsl}
    else
      if Ash.Resource.Info.data_layer(dsl) != AshPostgres.DataLayer do
        raise "AshAi vectorization only currently supports AshPostgres"
      end

      if Ash.Resource.Info.field(dsl, :full_text) do
        raise "AshAi vectorization currently does not work if there is a field called full_text"
      end

      attrs
      |> Enum.reduce({:ok, dsl}, &vectorize_attribute(&2, &1))
      |> full_text_vector()
      |> update_vectors_action()
    end
  end

  defbuilder update_vectors_action(dsl_state) do
    name = AshAi.Info.vectorize_full_text_name!(dsl_state)

    attrs =
      AshAi.Info.vectorize_attributes!(dsl_state)

    case AshAi.Info.vectorize_full_text_text(dsl_state) do
      {:ok, fun} ->
        used_attrs =
          case AshAi.Info.vectorize_full_text_used_attributes(dsl_state) do
            {:ok, attrs} -> attrs
            _ -> nil
          end

        attrs ++
          [{:full_text, name, used_attrs, fun}]

      _ ->
        attrs
    end
    |> case do
      [] ->
        {:ok, dsl_state}

      vectors ->
        strategy = AshAi.Info.vectorize_strategy!(dsl_state)

        case strategy do
          :after_action ->
            dsl_state
            |> add_change({AshAi.Changes.VectorizeAfterAction, [vectors: vectors]})
            |> add_new_action(:update, :ash_ai_update_embeddings,
              accept: Enum.map(vectors, &elem(&1, 1)),
              require_atomic?: false
            )

          :manual ->
            if AshAi.Info.vectorize_define_update_action_for_manual_strategy?(dsl_state) do
              dsl_state
              |> add_new_action(:update, :ash_ai_update_embeddings,
                accept: [],
                changes: [
                  %Ash.Resource.Change{
                    change: {AshAi.Changes.Vectorize, [vectors: vectors]},
                    on: nil,
                    only_when_valid?: true,
                    description: nil,
                    always_atomic?: false,
                    where: []
                  }
                ],
                require_atomic?: false
              )
            else
              {:ok, dsl_state}
            end

          :ash_oban ->
            if Code.ensure_loaded?(AshOban) do
              trigger_name = AshAi.Info.vectorize_ash_oban_trigger_name!(dsl_state)

              triggers =
                Spark.Dsl.Transformer.get_entities(dsl_state, [:oban, :triggers])

              trigger_defined? = Enum.any?(triggers, &(&1.name == trigger_name))

              if trigger_defined? do
                dsl_state
                |> add_change(
                  {AshAi.Changes.VectorizeAfterActionObanTrigger, [trigger_name: trigger_name]}
                )
                |> add_new_action(:update, :ash_ai_update_embeddings,
                  accept: [],
                  changes: [
                    %Ash.Resource.Change{
                      change: {AshAi.Changes.Vectorize, [vectors: vectors]},
                      on: nil,
                      only_when_valid?: true,
                      description: nil,
                      always_atomic?: false,
                      where: []
                    }
                  ],
                  require_atomic?: false
                )
              else
                raise "ash_oban-trigger :#{trigger_name} is not defined."
              end
            else
              raise "AshOban must be loaded in order to use the :ash_oban strategy, see README.md in ash_ai for instructions."
            end
        end
    end
  end

  defbuilder vectorize_attribute(dsl_state, {_source, dest}) do
    {embedding_model, opts} = AshAi.Info.vectorize_embedding_model!(dsl_state)

    dsl_state
    |> add_new_attribute(dest, :vector,
      constraints: [dimensions: embedding_model.dimensions(opts)],
      select_by_default?: false
    )
  end

  defbuilder full_text_vector(dsl_state) do
    name = AshAi.Info.vectorize_full_text_name!(dsl_state)

    {embedding_model, opts} = AshAi.Info.vectorize_embedding_model!(dsl_state)

    case AshAi.Info.vectorize_full_text_text(dsl_state) do
      {:ok, _fun} ->
        case AshAi.Info.vectorize_strategy!(dsl_state) do
          :after_action ->
            dsl_state
            |> add_new_attribute(name, :vector,
              constraints: [dimensions: embedding_model.dimensions(opts)],
              select_by_default?: false
            )

          :manual ->
            dsl_state
            |> add_new_attribute(name, :vector,
              constraints: [dimensions: embedding_model.dimensions(opts)],
              select_by_default?: false
            )

          :ash_oban ->
            dsl_state
            |> add_new_attribute(name, :vector,
              constraints: [dimensions: embedding_model.dimensions(opts)],
              select_by_default?: false
            )
        end

      _ ->
        {:ok, dsl_state}
    end
  end
end
