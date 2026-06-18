# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :domus, Domus.Repo,
  adapter: Ecto.Adapters.Postgres,
  migration_timestamps: [type: :utc_datetime]

config :domus,
  ecto_repos: [Domus.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :domus, DomusWeb.Endpoint,
  url: [host: "localhost"],
  
  render_errors: [
    formats: [html: DomusWeb.ErrorHTML, json: DomusWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Domus.PubSub,
  live_view: [signing_salt: "M9nglzFL"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  domus: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
