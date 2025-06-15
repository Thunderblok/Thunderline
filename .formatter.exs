[
  import_deps: [:ash, :ash_postgres, :ash_json_api, :phoenix, :broadway],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs:
    [
      "*.{ex,exs}",
      "{config,lib,test}/**/*.{ex,exs}",
      "priv/*/seeds.exs"
    ] -- ["lib/thunderline_web/live/components/tick_history_item.ex"]
]
