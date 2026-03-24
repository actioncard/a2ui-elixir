defmodule A2UI.Transport.A2ATest do
  use ExUnit.Case, async: false

  alias A2UI.Component
  alias A2UI.Protocol.Messages.{Action, CreateSurface, UpdateComponents}

  # -- Test A2UI Agent --

  defmodule UIAgent do
    @moduledoc false
    use A2UI.Agent

    def init(opts) do
      {:ok, %{test_pid: Keyword.get(opts, :test_pid)}}
    end

    @impl A2UI.Agent
    def handle_connect(conn, state) do
      A2UI.Agent.send_message(conn, %CreateSurface{
        surface_id: "main",
        catalog_id: "basic"
      })

      A2UI.Agent.send_message(conn, %UpdateComponents{
        surface_id: "main",
        components: [%Component{id: "root", type: "Container"}]
      })

      notify(state, {:connected, conn.id})
      {:noreply, state}
    end

    @impl A2UI.Agent
    def handle_action(action, conn, state) do
      A2UI.Agent.send_message(conn, %UpdateComponents{
        surface_id: "main",
        components: [
          %Component{id: "root", type: "Container", props: %{"action" => action.name}}
        ]
      })

      notify(state, {:action, action.name})
      {:noreply, state}
    end

    @impl A2UI.Agent
    def handle_disconnect(conn, state) do
      notify(state, {:disconnected, conn.id})
      {:noreply, state}
    end

    defp notify(%{test_pid: pid}, msg) when is_pid(pid), do: send(pid, msg)
    defp notify(_, _), do: :ok
  end

  # -- Test A2A Adapter --

  defmodule Adapter do
    @moduledoc false
    use A2UI.A2A,
      agent: A2UI.Transport.A2ATest.UIAgent,
      name: "test-client-adapter",
      description: "Test adapter for client transport"
  end

  setup do
    {:ok, ui} = UIAgent.start_link(test_pid: self(), name: UIAgent)
    {:ok, adapter} = Adapter.start_link()

    client =
      A2A.Client.new("http://test",
        plug: {A2A.Plug, agent: Adapter, base_url: "http://test"}
      )

    on_exit(fn ->
      safe_stop(adapter)
      safe_stop(ui)
    end)

    %{ui: ui, adapter: adapter, client: client}
  end

  defp safe_stop(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid, :normal, 100)
  catch
    :exit, _ -> :ok
  end

  test "connect delivers initial UI messages", %{client: client} do
    {:ok, transport} = A2UI.Transport.A2A.connect(client: client)

    assert_receive {:a2ui_message, %CreateSurface{surface_id: "main", catalog_id: "basic"}}
    assert_receive {:a2ui_message, %UpdateComponents{surface_id: "main"}}
    assert_receive {:connected, _}

    A2UI.Transport.A2A.disconnect(transport)
  end

  test "send_action forwards action and delivers response", %{client: client} do
    {:ok, transport} = A2UI.Transport.A2A.connect(client: client)

    assert_receive {:a2ui_message, %CreateSurface{}}
    assert_receive {:a2ui_message, %UpdateComponents{}}

    action = %Action{
      name: "submit",
      surface_id: "main",
      source_component_id: "btn1",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    :ok = A2UI.Transport.A2A.send_action(transport, action, %{})

    assert_receive {:a2ui_message, %UpdateComponents{surface_id: "main", components: comps}}
    assert hd(comps).props["action"] == "submit"
    assert_receive {:action, "submit"}

    A2UI.Transport.A2A.disconnect(transport)
  end

  test "disconnect stops handler", %{client: client} do
    {:ok, transport} = A2UI.Transport.A2A.connect(client: client)
    assert_receive {:a2ui_message, %CreateSurface{}}
    assert_receive {:a2ui_message, %UpdateComponents{}}

    handler = transport.handler
    assert Process.alive?(handler)

    A2UI.Transport.A2A.disconnect(transport)
    Process.sleep(50)
    refute Process.alive?(handler)
  end

  test "multi-turn uses same task for continuity", %{client: client} do
    {:ok, transport} = A2UI.Transport.A2A.connect(client: client)
    assert_receive {:a2ui_message, %CreateSurface{}}
    assert_receive {:a2ui_message, %UpdateComponents{}}

    # First action
    action1 = %Action{
      name: "click",
      surface_id: "main",
      source_component_id: "btn1",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    :ok = A2UI.Transport.A2A.send_action(transport, action1, %{})
    assert_receive {:a2ui_message, %UpdateComponents{}}
    assert_receive {:action, "click"}

    # Second action
    action2 = %Action{
      name: "change",
      surface_id: "main",
      source_component_id: "input1",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    :ok = A2UI.Transport.A2A.send_action(transport, action2, %{})
    assert_receive {:a2ui_message, %UpdateComponents{}}
    assert_receive {:action, "change"}

    A2UI.Transport.A2A.disconnect(transport)
  end
end
