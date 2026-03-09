defmodule A2UI.Demo.Endpoint do
  use Phoenix.Endpoint, otp_app: :a2ui

  @session_options [
    store: :cookie,
    key: "_a2ui_demo_key",
    signing_salt: "a2ui_demo_salt",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  plug(Plug.Static,
    at: "/",
    from: :a2ui,
    only: ~w(a2ui.css a2ui-hooks.js)
  )

  plug(Plug.Static,
    at: "/assets/phoenix",
    from: {:phoenix, "priv/static"},
    only: ~w(phoenix.min.js)
  )

  plug(Plug.Static,
    at: "/assets/phoenix_live_view",
    from: {:phoenix_live_view, "priv/static"},
    only: ~w(phoenix_live_view.min.js)
  )

  plug(Plug.RequestId)
  plug(Plug.Parsers, parsers: [:urlencoded, :multipart, :json], json_decoder: Jason)
  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(A2UI.Demo.Router)
end
