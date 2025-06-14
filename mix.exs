defmodule Thunderline.MixProject do
  use Mix.Project

  def project do
    [
      app: :thunderline,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      mod: {Thunderline.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix Framework
      {:phoenix, "~> 1.7.11"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},

      # Database
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},

      # Ash Framework
      {:ash, "~> 3.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_json_api, "~> 1.0"},      # Authentication (temporarily disabled on Windows)
      # {:ash_authentication, "~> 4.0"},
      # {:ash_authentication_phoenix, "~> 2.0"},# Job Processing & Stream Processing
      {:oban, "~> 2.17"},
      {:oban_web, "~> 2.10"},
      {:broadway, "~> 1.0"},
      {:broadway_sqs, "~> 0.7", optional: true},
      {:gen_stage, "~> 1.0"},      # HTTP Client & JSON
      {:req, "~> 0.5.0"},
      {:jason, "~> 1.2"},

      # AI & LLM
      {:ash_ai, "~> 0.1"},
      {:reactor, "~> 0.15"},
      {:langchain, "~> 0.3.0-rc.0"},
      {:ex_openai, "~> 1.0"},

      # Vector Search & Memory
      {:pgvector, "~> 0.2.0"},
      {:nx, "~> 0.7.0"},
      {:bumblebee, "~> 0.5.0"},      # Jido Framework (for agent workflows)
      {:jido, github: "agentjido/jido", branch: "main"},
      {:jido_signal, github: "agentjido/jido_signal", branch: "main"},

      # MCP (Model Context Protocol)
      {:websock_adapter, "~> 0.5.3"},
      {:bandit, "~> 1.0"},

      # Utilities
      {:floki, ">= 0.30.0", only: :test},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:plug_cowboy, "~> 2.5"},
      {:cors_plug, "~> 3.0"},
      {:uuid, "~> 1.1"},
      {:timex, "~> 3.7"},
      {:typed_struct, "~> 0.3.0"},
      {:uniq, "~> 0.6"},
      {:deep_merge, "~> 1.0"},
      {:nimble_options, "~> 1.0"},
      {:nimble_parsec, "~> 1.0"},
      {:ok, "~> 2.3"},
      {:msgpax, "~> 2.3"},
      {:backoff, "~> 1.1"},
      {:abacus, "~> 2.0"},
      {:quantum, "~> 3.0"},
      {:proper_case, "~> 1.3"},

      # Development
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.13"},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end

  defp releases do
    [
      thunderline: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent]
      ]
    ]
  end
end
