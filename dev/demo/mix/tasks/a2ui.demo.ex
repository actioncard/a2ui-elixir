defmodule Mix.Tasks.A2ui.Demo do
  @moduledoc """
  Starts the A2UI demo server.

      $ mix a2ui.demo

  Opens a restaurant booking demo at http://localhost:4002
  """

  use Mix.Task

  @shortdoc "Starts the A2UI demo server"

  # Mix.Task behaviour and functions aren't in the PLT (build tool, not runtime dep)
  @dialyzer [:no_undefined_callbacks, {:nowarn_function, run: 1}]

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    endpoint_config = Application.get_env(:a2ui, A2UI.Demo.Endpoint, [])
    Application.put_env(:a2ui, A2UI.Demo.Endpoint, Keyword.put(endpoint_config, :server, true))

    {:ok, _} = A2UI.Demo.Agent.start_link(name: A2UI.Demo.Agent)
    {:ok, _} = A2UI.Demo.A2AAdapter.start_link()
    {:ok, _} = A2UI.Demo.Endpoint.start_link()

    Mix.shell().info("""

    A2UI Demo running:

      Local transport:  http://localhost:4002
      A2A transport:    http://localhost:4002/a2a

    Press Ctrl+C to stop.
    """)

    Process.sleep(:infinity)
  end
end
