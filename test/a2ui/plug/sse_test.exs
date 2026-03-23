defmodule A2UI.Plug.SSETest do
  use ExUnit.Case, async: true

  alias A2UI.Connection
  alias A2UI.Plug.ConnectionRegistry
  alias A2UI.Protocol.Messages.{CreateSurface, UpdateComponents}
  alias A2UI.Component

  defmodule EchoAgent do
    @moduledoc false
    use A2UI.Agent

    def init(opts), do: {:ok, Keyword.get(opts, :test_pid)}

    @impl A2UI.Agent
    def handle_connect(conn, test_pid) do
      A2UI.Agent.send_message(conn, %CreateSurface{
        surface_id: "main",
        catalog_id: "basic"
      })

      A2UI.Agent.send_message(conn, %UpdateComponents{
        surface_id: "main",
        components: [
          %Component{id: "root", type: "Text", props: %{"text" => "Hello"}}
        ]
      })

      send(test_pid, {:agent_connected, conn})
      {:noreply, test_pid}
    end

    @impl A2UI.Agent
    def handle_action(action, _conn, test_pid) do
      send(test_pid, {:agent_action, action.name})
      {:noreply, test_pid}
    end
  end

  setup do
    table = :"sse_registry_#{:erlang.unique_integer([:positive])}"
    ConnectionRegistry.ensure_started(table)

    {:ok, agent} = EchoAgent.start_link(test_pid: self())

    %{agent: agent, table: table}
  end

  test "SSE handler connects to agent and streams messages", %{agent: agent, table: table} do
    test_pid = self()

    # Spawn the SSE handler in a separate process (it blocks)
    spawn_link(fn ->
      # We can't use Plug.Test with chunked responses directly,
      # so we test the connection flow by simulating what SSE.stream does:
      # create Connection, register, connect to agent, receive messages.
      connection = %Connection{
        id: "test-sse-#{:erlang.unique_integer([:positive])}",
        transport: A2UI.Transport.SSE,
        ref: self(),
        pid: self()
      }

      ConnectionRegistry.register(connection.id, self(), table)
      send(agent, {:a2ui_connect, connection})

      # Wait for messages from agent
      messages =
        receive do
          {:a2ui_deliver, msg1} ->
            receive do
              {:a2ui_deliver, msg2} -> [msg1, msg2]
            after
              500 -> [msg1]
            end
        after
          1000 -> []
        end

      send(test_pid, {:sse_messages, messages, connection.id})

      # Keep process alive so registry lookup succeeds
      receive do
        :done -> :ok
      end
    end)

    assert_receive {:agent_connected, %Connection{}}, 1000
    assert_receive {:sse_messages, messages, conn_id}, 2000

    assert length(messages) == 2
    assert %CreateSurface{surface_id: "main"} = Enum.at(messages, 0)
    assert %UpdateComponents{surface_id: "main"} = Enum.at(messages, 1)

    # Verify registry has the connection
    assert {:ok, _pid} = ConnectionRegistry.lookup(conn_id, table)
  end

  test "unregister removes connection from registry", %{table: table} do
    handler =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    ConnectionRegistry.register("cleanup-test", handler, table)
    assert {:ok, ^handler} = ConnectionRegistry.lookup("cleanup-test", table)

    ConnectionRegistry.unregister("cleanup-test", table)
    assert {:error, :not_found} = ConnectionRegistry.lookup("cleanup-test", table)

    send(handler, :stop)
  end
end
