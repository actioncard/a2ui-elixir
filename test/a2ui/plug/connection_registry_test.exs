defmodule A2UI.Plug.ConnectionRegistryTest do
  use ExUnit.Case, async: true

  alias A2UI.Plug.ConnectionRegistry

  setup do
    # Use a unique table name per test to avoid conflicts
    table = :"registry_#{:erlang.unique_integer([:positive])}"
    ConnectionRegistry.ensure_started(table)
    %{table: table}
  end

  test "register and lookup", %{table: table} do
    ConnectionRegistry.register("conn-1", self(), table)
    assert {:ok, pid} = ConnectionRegistry.lookup("conn-1", table)
    assert pid == self()
  end

  test "lookup returns error for unknown id", %{table: table} do
    assert {:error, :not_found} = ConnectionRegistry.lookup("unknown", table)
  end

  test "unregister removes entry", %{table: table} do
    ConnectionRegistry.register("conn-1", self(), table)
    assert {:ok, _} = ConnectionRegistry.lookup("conn-1", table)

    ConnectionRegistry.unregister("conn-1", table)
    assert {:error, :not_found} = ConnectionRegistry.lookup("conn-1", table)
  end

  test "auto-cleanup on process death via monitor", %{table: table} do
    pid =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    ConnectionRegistry.register("conn-1", pid, table)
    assert {:ok, ^pid} = ConnectionRegistry.lookup("conn-1", table)

    send(pid, :stop)
    Process.sleep(50)

    # GenServer receives :DOWN and deletes the entry
    assert {:error, :not_found} = ConnectionRegistry.lookup("conn-1", table)
  end

  test "ensure_started is idempotent", %{table: table} do
    assert :ok = ConnectionRegistry.ensure_started(table)
    assert :ok = ConnectionRegistry.ensure_started(table)
  end
end
