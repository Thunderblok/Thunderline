defmodule AshAi.Info do
  @moduledoc "Introspection functions for the `AshAi` extension."
  use Spark.InfoGenerator, extension: AshAi, sections: [:tools, :vectorize]
end
