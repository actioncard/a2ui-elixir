if Code.ensure_loaded?(Plug) do
  defmodule A2UI.Plug.ConnectionRegistry do
    @moduledoc """
    ETS-based registry mapping SSE connection IDs to handler pids.

    Used by `A2UI.Plug.SSE` and `A2UI.Plug.JSONRPC` to route JSON-RPC
    requests to the correct SSE handler process. Monitors registered
    pids and auto-cleans entries when a handler exits.

    ## Supervised usage (recommended for production)

    Add to your application's supervision tree:

        children = [
          A2UI.Plug.ConnectionRegistry,
          # ...
        ]

    ## Lazy usage (development / testing)

    `A2UI.Plug` calls `ensure_started/0` automatically on first
    request. The registry runs unsupervised in this mode — acceptable
    for development but not recommended for production.

    ## Design note: why `ensure_started` is in `call/2`, not `init/1`

    Phoenix calls `Plug.init/1` at **compile time** during router macro
    expansion. Spawning a GenServer there either fails (application not
    started) or creates an orphan process that is destroyed when the
    compiler finishes. `ensure_started/1` is called from `call/2`
    instead — the happy path is a single `:ets.whereis` NIF call (~ns).
    In production the supervision tree starts the registry before any
    request arrives, making the `call/2` check a no-op.
    """

    use GenServer

    @default_table __MODULE__

    # -- Lifecycle -----------------------------------------------------------

    @doc """
    Starts the registry as a linked process (for supervision trees).
    """
    @spec start_link(keyword()) :: GenServer.on_start()
    def start_link(opts \\ []) do
      table = Keyword.get(opts, :table, @default_table)
      GenServer.start_link(__MODULE__, table, name: table)
    end

    @doc """
    Ensures the registry is running. Starts an unlinked process if not
    already started. Safe to call multiple times — the happy path is a
    single `:ets.whereis` check.
    """
    @spec ensure_started(atom()) :: :ok
    def ensure_started(table \\ @default_table) do
      if :ets.whereis(table) != :undefined do
        :ok
      else
        case GenServer.start(__MODULE__, table, name: table) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
        end
      end
    end

    @impl GenServer
    def init(table) do
      :ets.new(table, [:named_table, :public, :set])
      {:ok, %{table: table, monitors: %{}}}
    end

    # -- Public API ----------------------------------------------------------

    @doc """
    Registers a connection ID to a handler pid.

    The registry monitors the pid and auto-removes the entry if the
    handler process exits without calling `unregister/2`.
    """
    @spec register(String.t(), pid(), atom()) :: :ok
    def register(conn_id, pid, table \\ @default_table) do
      GenServer.call(table, {:register, conn_id, pid})
    end

    @doc """
    Looks up the handler pid for a connection ID.
    """
    @spec lookup(String.t(), atom()) :: {:ok, pid()} | {:error, :not_found}
    def lookup(conn_id, table \\ @default_table) do
      case :ets.lookup(table, conn_id) do
        [{^conn_id, pid}] -> {:ok, pid}
        [] -> {:error, :not_found}
      end
    end

    @doc """
    Removes a connection from the registry.
    """
    @spec unregister(String.t(), atom()) :: :ok
    def unregister(conn_id, table \\ @default_table) do
      GenServer.call(table, {:unregister, conn_id})
    end

    # -- GenServer callbacks -------------------------------------------------

    @impl GenServer
    def handle_call({:register, conn_id, pid}, _from, state) do
      ref = Process.monitor(pid)
      :ets.insert(state.table, {conn_id, pid})
      {:reply, :ok, %{state | monitors: Map.put(state.monitors, ref, conn_id)}}
    end

    def handle_call({:unregister, conn_id}, _from, state) do
      :ets.delete(state.table, conn_id)

      case Enum.find(state.monitors, fn {_ref, id} -> id == conn_id end) do
        {ref, _id} ->
          Process.demonitor(ref, [:flush])
          {:reply, :ok, %{state | monitors: Map.delete(state.monitors, ref)}}

        nil ->
          {:reply, :ok, state}
      end
    end

    @impl GenServer
    def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
      case Map.pop(state.monitors, ref) do
        {nil, monitors} ->
          {:noreply, %{state | monitors: monitors}}

        {conn_id, monitors} ->
          :ets.delete(state.table, conn_id)
          {:noreply, %{state | monitors: monitors}}
      end
    end
  end
end
