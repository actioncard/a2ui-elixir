defmodule Mix.Tasks.A2ui.Demo do
  @moduledoc """
  Starts the A2UI demo server.

      $ mix a2ui.demo

  Opens a restaurant booking demo at http://localhost:4002
  """

  use Mix.Task

  @shortdoc "Starts the A2UI demo server"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    endpoint_config = Application.get_env(:a2ui, A2UI.Demo.Endpoint, [])
    Application.put_env(:a2ui, A2UI.Demo.Endpoint, Keyword.put(endpoint_config, :server, true))

    {:ok, _} = A2UI.Demo.Agent.start_link(name: A2UI.Demo.Agent)
    {:ok, _} = A2UI.Demo.Endpoint.start_link()

    Mix.shell().info("""

    A2UI Demo running at http://localhost:4002

    Press Ctrl+C to stop.
    """)

    Process.sleep(:infinity)
  end
end
