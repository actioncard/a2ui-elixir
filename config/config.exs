import Config

config :bun,
  version: "1.2.5",
  test: [
    args: ~w(test),
    cd: Path.expand("..", __DIR__)
  ]

import_config "#{config_env()}.exs"
