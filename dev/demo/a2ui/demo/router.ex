defmodule A2UI.Demo.Router do
  use Phoenix.Router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {A2UI.Demo.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  forward "/a2a-endpoint", A2A.Plug,
    agent: A2UI.Demo.A2AAdapter,
    base_url: "http://localhost:4002/a2a-endpoint"

  scope "/" do
    pipe_through(:browser)
    live("/", A2UI.Demo.DemoLive)
    live("/a2a", A2UI.Demo.A2ALive)
  end
end
