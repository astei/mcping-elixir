defmodule MCPing.MixProject do
  use Mix.Project

  def project do
    [
      app: :mcping,
      version: "0.2.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      source_url: "https://github.com/astei/mcping-elixir"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:varint, "~> 1.3"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.29.4", only: :dev}
    ]
  end

  defp package do
    [
      description: "A simple library to ping Minecraft: Java Edition servers using Elixir.",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/astei/mcping-elixir"},
      maintainers: ["Andrew Steinborn"]
    ]
  end
end
