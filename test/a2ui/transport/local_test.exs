defmodule A2UI.Transport.LocalTest do
  use ExUnit.Case, async: true

  alias A2UI.Connection
  alias A2UI.Transport.Local
  alias A2UI.Protocol.Messages.{Action, Error}

  test "connect sends {:a2ui_connect, %Connection{}} to agent" do
    agent = self()
    assert {:ok, transport} = Local.connect(agent: agent)
    assert_received {:a2ui_connect, %Connection{} = conn}
    assert conn.pid == self()
    assert conn.ref == self()
    assert conn.transport == Local
    assert is_binary(conn.id)
    assert transport.agent == agent
    assert transport.connection == conn
  end

  test "send_action sends {:a2ui_action, action, metadata} to agent" do
    agent = self()
    {:ok, transport} = Local.connect(agent: agent)
    assert_received {:a2ui_connect, %Connection{} = conn}

    action = %Action{name: "submit", surface_id: "s1", source_component_id: "btn1"}
    metadata = %{foo: "bar"}

    assert :ok = Local.send_action(transport, action, metadata)
    assert_received {:a2ui_action, ^action, received_meta}
    assert received_meta.foo == "bar"
    assert received_meta.connection == conn
  end

  test "send_error sends {:a2ui_error, error, metadata} to agent" do
    agent = self()
    {:ok, transport} = Local.connect(agent: agent)
    assert_received {:a2ui_connect, %Connection{} = conn}

    error = %Error{
      code: "VALIDATION_FAILED",
      surface_id: "s1",
      path: "/name",
      message: "Required"
    }

    metadata = %{foo: "bar"}

    assert :ok = Local.send_error(transport, error, metadata)
    assert_received {:a2ui_error, ^error, received_meta}
    assert received_meta.foo == "bar"
    assert received_meta.connection == conn
  end

  test "disconnect sends {:a2ui_disconnect, %Connection{}} to agent" do
    agent = self()
    {:ok, transport} = Local.connect(agent: agent)
    assert_received {:a2ui_connect, %Connection{} = conn}

    assert :ok = Local.disconnect(transport)
    assert_received {:a2ui_disconnect, ^conn}
  end

  test "deliver_message sends {:a2ui_message, msg} to pid" do
    msg = %A2UI.Protocol.Messages.CreateSurface{surface_id: "s1", catalog_id: "basic"}
    assert :ok = Local.deliver_message(self(), msg)
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
        transport.connection.pid
      end)

    liveview_pid = Task.await(task)
    assert_received {:a2ui_connect, %Connection{pid: ^liveview_pid}}
    assert liveview_pid != self()
  end
end
