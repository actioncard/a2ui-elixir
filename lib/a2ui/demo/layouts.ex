defmodule A2UI.Demo.Layouts do
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <title>A2UI Demo</title>
        <link rel="stylesheet" href="/a2ui.css" />
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f5f5f5; color: #1a1a1a; }
          .demo-container { max-width: 600px; margin: 2rem auto; padding: 0 1rem; }
          .demo-header { text-align: center; padding: 1rem 0; color: #666; font-size: 0.85rem; }
        </style>
      </head>
      <body>
        <script src="/assets/phoenix/phoenix.min.js"></script>
        <script src="/assets/phoenix_live_view/phoenix_live_view.min.js"></script>
        {@inner_content}
        <script>
          let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
          let liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {params: {_csrf_token: csrfToken}});
          liveSocket.connect();
        </script>
      </body>
    </html>
    """
  end

  def app(assigns) do
    ~H"""
    <div class="demo-container">
      <div class="demo-header">A2UI v0.9 Demo</div>
      {@inner_content}
    </div>
    """
  end
end
