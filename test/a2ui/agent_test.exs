defmodule A2UI.AgentTest do
  use ExUnit.Case, async: true

  alias A2UI.Protocol.Messages.Action

  defmodule TestAgent do
    @moduledoc false
    use A2UI.Agent

    def init(opts) do
      {:ok, %{events: [], test_pid: Keyword.get(opts, :test_pid)}}
    end

    @impl A2UI.Agent
    def handle_connect(conn, state) do
      notify(state, {:connected, conn})
      {:noreply, %{state | events: [{:connect, conn} | state.events]}}
    end

    @impl A2UI.Agent
    def handle_action(action, conn, state) do
      notify(state, {:action, action.name, conn})
      {:noreply, %{state | events: [{:action, action.name, conn} | state.events]}}
    end

    @impl A2UI.Agent
    def handle_disconnect(conn, state) do
      notify(state, {:disconnected, conn})
      {:noreply, %{state | events: [{:disconnect, conn} | state.events]}}
    end

    def handle_info({:custom, data}, state) do
      notify(state, {:custom_info, data})
      {:noreply, %{state | events: [{:custom_info, data} | state.events]}}
    end

    def handle_info(_msg, state), do: {:noreply, state}

    defp notify(%{test_pid: pid}, msg) when is_pid(pid), do: send(pid, msg)
    defp notify(_, _), do: :ok
  end

  defmodule MinimalAgent do
    @moduledoc false
    use A2UI.Agent

    def init(opts), do: {:ok, Keyword.get(opts, :test_pid)}

    @impl A2UI.Agent
    def handle_connect(conn, test_pid) do
      send(test_pid, {:connected, conn})
      {:noreply, test_pid}
    end

    @impl A2UI.Agent
    def handle_action(_action, _conn, state), do: {:noreply, state}
  end

  defmodule StopAgent do
    @moduledoc false
    use A2UI.Agent

    def init(_opts), do: {:stop, :bad_config}

    @impl A2UI.Agent
    def handle_connect(_conn, state), do: {:noreply, state}

    @impl A2UI.Agent
    def handle_action(_action, _conn, state), do: {:noreply, state}
  end

  describe "init/1" do
    test "passes opts to agent init callback" do
      {:ok, pid} = TestAgent.start_link(test_pid: self())
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "propagates {:stop, reason}" do
      Process.flag(:trap_exit, true)
      assert {:error, :bad_config} = StopAgent.start_link()
    end
  end

  describe "handle_connect" do
    test "fires callback and monitors the connection" do
      {:ok, agent} = TestAgent.start_link(test_pid: self())
      send(agent, {:a2ui_connect, self()})
      assert_receive {:connected, pid} when pid == self()
      GenServer.stop(agent)
    end

    test "sends messages to the connected LiveView" do
      {:ok, agent} = TestAgent.start_link(test_pid: self())
      send(agent, {:a2ui_connect, self()})
      assert_receive {:connected, _}
      GenServer.stop(agent)
    end
  end

  describe "handle_action" do
    test "routes action with liveview_pid metadata" do
      {:ok, agent} = TestAgent.start_link(test_pid: self())
      send(agent, {:a2ui_connect, self()})
      assert_receive {:connected, _}

      action = %Action{
        name: "test_action",
        surface_id: "main",
        source_component_id: "btn",
        context: %{}
      }

      send(agent, {:a2ui_action, action, %{liveview_pid: self()}})
      assert_receive {:action, "test_action", pid} when pid == self()
      GenServer.stop(agent)
    end

    test "silently ignores action with nil pid" do
      {:ok, agent} = TestAgent.start_link(test_pid: self())

      action = %Action{
        name: "test_action",
        surface_id: "main",
        source_component_id: "btn",
        context: %{}
      }

      send(agent, {:a2ui_action, action, %{}})
      refute_receive {:action, _, _}, 50
      GenServer.stop(agent)
    end
  end

  describe "handle_disconnect" do
    test "fires on explicit disconnect" do
      {:ok, agent} = TestAgent.start_link(test_pid: self())
      send(agent, {:a2ui_connect, self()})
      assert_receive {:connected, _}

      send(agent, {:a2ui_disconnect, self()})
      assert_receive {:disconnected, pid} when pid == self()
      GenServer.stop(agent)
    end

    test "fires on monitored process death" do
      {:ok, agent} = TestAgent.start_link(test_pid: self())

      child =
        spawn(fn ->
          receive do
            :stop -> :ok
          end
        end)

      send(agent, {:a2ui_connect, child})
      assert_receive {:connected, ^child}

      send(child, :stop)
      assert_receive {:disconnected, ^child}, 500
      GenServer.stop(agent)
    end

    test "ignores DOWN from non-connected process" do
      {:ok, agent} = TestAgent.start_link(test_pid: self())

      send(agent, {:DOWN, make_ref(), :process, self(), :normal})
      refute_receive {:disconnected, _}, 50
      GenServer.stop(agent)
    end
  end

  describe "default handle_disconnect" do
    test "minimal agent without handle_disconnect does not crash" do
      {:ok, agent} = MinimalAgent.start_link(test_pid: self())
      send(agent, {:a2ui_connect, self()})
      assert_receive {:connected, _}

      send(agent, {:a2ui_disconnect, self()})
      :timer.sleep(50)
      assert Process.alive?(agent)
      GenServer.stop(agent)
    end
  end

  describe "handle_info passthrough" do
    test "routes non-A2UI messages to agent callback" do
      {:ok, agent} = TestAgent.start_link(test_pid: self())
      send(agent, {:custom, :hello})
      assert_receive {:custom_info, :hello}
      GenServer.stop(agent)
    end
  end

  describe "send_message/2" do
    test "delivers message as {:a2ui_message, _}" do
      A2UI.Agent.send_message(self(), :test_msg)
      assert_receive {:a2ui_message, :test_msg}
    end
  end

  describe "send_messages/2" do
    test "delivers all messages in order" do
      A2UI.Agent.send_messages(self(), [:msg1, :msg2, :msg3])
      assert_receive {:a2ui_message, :msg1}
      assert_receive {:a2ui_message, :msg2}
      assert_receive {:a2ui_message, :msg3}
    end
  end

  describe "named registration" do
    test "start_link with :name option" do
      {:ok, pid} = TestAgent.start_link(name: :test_agent, test_pid: self())
      assert Process.whereis(:test_agent) == pid
      GenServer.stop(pid)
    end
  end
end
