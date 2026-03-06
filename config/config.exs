import Config

config :a2ui, A2UI.Demo.Endpoint,
  http: [port: 4002],
  server: false,
  adapter: Bandit.PhoenixAdapter,
  secret_key_base: String.duplicate("a2ui_demo_secret_", 4),
  live_view: [signing_salt: "a2ui_demo_salt"],
  render_errors: [formats: [html: A2UI.Demo.ErrorHTML], layout: false]
