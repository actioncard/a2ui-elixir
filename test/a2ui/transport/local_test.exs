defmodule A2UI.Transport.LocalTest do
  use ExUnit.Case, async: true

  alias A2UI.Transport.Local
  alias A2UI.Protocol.Messages.Action

  test "connect sends {:a2ui_connect, pid} to agent" do
    agent = self()
    assert {:ok, transport} = Local.connect(agent: agent)
    assert_received {:a2ui_connect, pid}
    assert pid == self()
    assert transport.agent == agent
    assert transport.liveview == self()
  end

  test "send_action sends {:a2ui_action, action, metadata} to agent" do
    agent = self()
    {:ok, transport} = Local.connect(agent: agent)
    # Drain the connect message
    assert_received {:a2ui_connect, _}

    action = %Action{name: "submit", surface_id: "s1", source_component_id: "btn1"}
    metadata = %{foo: "bar"}

    assert :ok = Local.send_action(transport, action, metadata)
    assert_received {:a2ui_action, ^action, ^metadata}
  end

  test "disconnect sends {:a2ui_disconnect, pid} to agent" do
    agent = self()
    {:ok, transport} = Local.connect(agent: agent)
    assert_received {:a2ui_connect, _}

    assert :ok = Local.disconnect(transport)
    assert_received {:a2ui_disconnect, pid}
    assert pid == self()
  end

  test "agent can send {:a2ui_message, msg} back to liveview" do
    # Simulate agent sending a message to the liveview process
    liveview = self()
    msg = %A2UI.Protocol.Messages.CreateSurface{surface_id: "s1", catalog_id: "basic"}
    send(liveview, {:a2ui_message, msg})

    assert_received {:a2ui_message, ^msg}
  end

  test "connect requires agent option" do
    assert_raise KeyError, fn ->
      Local.connect([])
    end
  end

  test "multiple connects from different processes" do
    agent = self()

    task =
      Task.async(fn ->
        {:ok, transport} = Local.connect(agent: agent)
        transport.liveview
      end)

    liveview_pid = Task.await(task)
    assert_received {:a2ui_connect, ^liveview_pid}
    assert liveview_pid != self()
  end
end
