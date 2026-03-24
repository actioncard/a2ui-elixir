defmodule A2UI.A2ATest do
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
    def handle_error(error, _conn, state) do
      notify(state, {:error, error.code})
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
      agent: A2UI.A2ATest.UIAgent,
      name: "test-a2a-adapter",
      description: "Test adapter"
  end

  setup do
    {:ok, ui} = UIAgent.start_link(test_pid: self(), name: UIAgent)
    {:ok, adapter} = Adapter.start_link()

    on_exit(fn ->
      safe_stop(adapter)
      safe_stop(ui)
    end)

    %{ui: ui, adapter: adapter}
  end

  defp safe_stop(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid, :normal, 100)
  catch
    :exit, _ -> :ok
  end

  test "first message triggers handle_connect and returns UI messages", %{adapter: adapter} do
    msg = A2A.Message.new_user("connect")
    {:ok, task} = A2A.call(adapter, msg)

    assert task.status.state == :input_required
    assert_receive {:connected, _conn_id}

    parts = task.status.message.parts
    assert length(parts) == 2

    [create, update] = parts
    assert %A2A.Part.Data{data: %{"version" => "v0.9", "createSurface" => cs}} = create
    assert cs["surfaceId"] == "main"
    assert cs["catalogId"] == "basic"

    assert %A2A.Part.Data{data: %{"version" => "v0.9", "updateComponents" => uc}} = update
    assert uc["surfaceId"] == "main"
  end

  test "continuation with action triggers handle_action", %{adapter: adapter} do
    # Connect first
    {:ok, task} = A2A.call(adapter, A2A.Message.new_user("connect"))
    assert_receive {:connected, _}

    # Send action
    action_map =
      Action.to_map(%Action{
        name: "submit",
        surface_id: "main",
        source_component_id: "btn1",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    action_msg = A2A.Message.new_user([A2A.Part.Data.new(action_map)])
    {:ok, task2} = A2A.call(adapter, action_msg, task_id: task.id)

    assert task2.status.state == :input_required
    assert_receive {:action, "submit"}

    [update] = task2.status.message.parts
    assert %A2A.Part.Data{data: %{"version" => "v0.9", "updateComponents" => uc}} = update
    assert hd(uc["components"])["action"] == "submit"
  end

  test "error forwarding", %{adapter: adapter} do
    {:ok, task} = A2A.call(adapter, A2A.Message.new_user("connect"))
    assert_receive {:connected, _}

    error_map =
      A2UI.Protocol.Messages.Error.to_map(%A2UI.Protocol.Messages.Error{
        code: "VALIDATION_FAILED",
        surface_id: "main",
        path: "name",
        message: "required"
      })

    error_msg = A2A.Message.new_user([A2A.Part.Data.new(error_map)])
    {:ok, _task2} = A2A.call(adapter, error_msg, task_id: task.id)

    assert_receive {:error, "VALIDATION_FAILED"}
  end

  test "cancel triggers handle_disconnect", %{adapter: adapter} do
    {:ok, task} = A2A.call(adapter, A2A.Message.new_user("connect"))
    assert_receive {:connected, conn_id}

    :ok = Adapter.cancel(adapter, task.id)
    assert_receive {:disconnected, ^conn_id}
  end

  test "multiple turns maintain same connection", %{adapter: adapter} do
    {:ok, task} = A2A.call(adapter, A2A.Message.new_user("connect"))
    assert_receive {:connected, conn_id}

    action_map =
      Action.to_map(%Action{
        name: "click",
        surface_id: "main",
        source_component_id: "btn1",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    {:ok, _} =
      A2A.call(adapter, A2A.Message.new_user([A2A.Part.Data.new(action_map)]), task_id: task.id)

    assert_receive {:action, "click"}

    # Second action on same task
    action_map2 =
      Action.to_map(%Action{
        name: "change",
        surface_id: "main",
        source_component_id: "input1",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    {:ok, _} =
      A2A.call(adapter, A2A.Message.new_user([A2A.Part.Data.new(action_map2)]), task_id: task.id)

    assert_receive {:action, "change"}
    # Still connected, no disconnect
    refute_received {:disconnected, ^conn_id}
  end
end
