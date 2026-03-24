defmodule A2UI.Agent do
  @moduledoc """
  Behaviour and macro for building A2UI agents.

  `use A2UI.Agent` eliminates GenServer boilerplate for agents that serve A2UI
  protocol messages to connected clients. Agents implement only the callbacks
  that matter: `init/1`, `handle_connect/2`, and `handle_action/3`.

  ## Example

      defmodule MyAgent do
        use A2UI.Agent

        def init(_opts), do: {:ok, %{}}

        @impl A2UI.Agent
        def handle_connect(conn, state) do
          A2UI.Agent.send_message(conn, %CreateSurface{surface_id: "main"})
          {:noreply, state}
        end

        @impl A2UI.Agent
        def handle_action(action, conn, state) do
          IO.inspect(action.name)
          {:noreply, state}
        end
      end

  ## Callbacks

  Required:
  - `init/1` — receives keyword opts, returns `{:ok, state}` or `{:stop, reason}`
  - `handle_connect/2` — called when a client connects
  - `handle_action/3` — called when a user triggers an action

  Optional (default no-op):
  - `handle_disconnect/2` — called when a client disconnects or its process dies
  - `handle_info/2` — called for any non-A2UI messages
  """

  require Logger

  alias A2UI.Connection

  @type conn :: Connection.t()
  @type state :: term()

  @callback handle_connect(conn, state) :: {:noreply, state}
  @callback handle_action(A2UI.Protocol.Messages.Action.t(), conn, state) :: {:noreply, state}
  @callback handle_error(A2UI.Protocol.Messages.Error.t(), conn, state) :: {:noreply, state}
  @callback handle_disconnect(conn, state) :: {:noreply, state}

  @optional_callbacks [handle_disconnect: 2, handle_error: 3]

  defmodule State do
    @moduledoc false
    defstruct connections: %{}, agent_state: nil
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour A2UI.Agent
      use GenServer

      @before_compile A2UI.Agent

      @doc """
      Starts the agent as a linked process.

      Accepts keyword options. `:name` is passed to `GenServer.start_link/3`;
      remaining options are forwarded to the `init/1` callback.
      """
      def start_link(opts \\ []) do
        {name, opts} = Keyword.pop(opts, :name)
        GenServer.start_link(__MODULE__, opts, name: name)
      end

      # -- Default implementations (user overrides these) --

      def init(_opts), do: {:ok, nil}

      @impl A2UI.Agent
      def handle_error(_error, _conn, state), do: {:noreply, state}

      @impl A2UI.Agent
      def handle_disconnect(_conn, state), do: {:noreply, state}

      def handle_info(_msg, state), do: {:noreply, state}

      defoverridable start_link: 1,
                     init: 1,
                     handle_error: 3,
                     handle_disconnect: 2,
                     handle_info: 2
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # Mark user-defined (or default) init/1 and handle_info/2 as overridable
      # so the GenServer wrappers below can call them via super/1 and super/2.
      defoverridable init: 1, handle_info: 2

      @doc false
      @impl GenServer
      def init(opts) do
        A2UI.Agent.__wrap_init__(super(opts))
      end

      @doc false
      @impl GenServer
      def handle_info(msg, %A2UI.Agent.State{} = state) do
        A2UI.Agent.__handle_info__(__MODULE__, &super/2, msg, state)
      end
    end
  end

  # -- Helper functions --

  @doc """
  Sends a single A2UI protocol message to a connected client.

  Dispatches through the connection's transport module.
  """
  @spec send_message(conn, struct()) :: :ok | {:error, any()} when conn: Connection.t()
  def send_message(%Connection{transport: transport, ref: ref}, message) do
    transport.deliver_message(ref, message)
  end

  @doc """
  Sends a list of A2UI protocol messages to a connected client.

  Dispatches through the connection's transport module. This is a
  fire-and-forget operation — individual delivery failures are silently
  ignored. Use `send_message/2` for per-message error handling.
  """
  @spec send_messages(conn, [struct()]) :: :ok when conn: Connection.t()
  def send_messages(%Connection{} = conn, messages) do
    Enum.each(messages, fn msg -> send_message(conn, msg) end)
    :ok
  end

  # -- Internal functions called from injected code --

  @doc false
  def __wrap_init__(result) do
    case result do
      {:ok, agent_state} ->
        {:ok, %State{agent_state: agent_state}}

      {:stop, reason} ->
        {:stop, reason}
    end
  end

  @doc false
  def __handle_info__(module, _super_fn, {:a2ui_connect, %Connection{} = conn}, %State{} = state) do
    ref = Process.monitor(conn.pid)
    connections = Map.put(state.connections, conn.id, {conn, ref})

    case module.handle_connect(conn, state.agent_state) do
      {:noreply, agent_state} ->
        {:noreply, %{state | connections: connections, agent_state: agent_state}}
    end
  end

  def __handle_info__(module, _super_fn, {:a2ui_action, action, metadata}, %State{} = state) do
    conn = Map.get(metadata, :connection)

    if conn do
      case module.handle_action(action, conn, state.agent_state) do
        {:noreply, agent_state} ->
          {:noreply, %{state | agent_state: agent_state}}
      end
    else
      Logger.warning("#{inspect(module)} received :a2ui_action without :connection in metadata")
      {:noreply, state}
    end
  end

  def __handle_info__(module, _super_fn, {:a2ui_error, error, metadata}, %State{} = state) do
    conn = Map.get(metadata, :connection)

    if conn do
      case module.handle_error(error, conn, state.agent_state) do
        {:noreply, agent_state} ->
          {:noreply, %{state | agent_state: agent_state}}
      end
    else
      Logger.warning("#{inspect(module)} received :a2ui_error without :connection in metadata")
      {:noreply, state}
    end
  end

  def __handle_info__(
        module,
        _super_fn,
        {:a2ui_disconnect, %Connection{} = conn},
        %State{} = state
      ) do
    case Map.pop(state.connections, conn.id) do
      {{_conn, ref}, connections} ->
        Process.demonitor(ref, [:flush])

        case module.handle_disconnect(conn, state.agent_state) do
          {:noreply, agent_state} ->
            {:noreply, %{state | connections: connections, agent_state: agent_state}}
        end

      {nil, _connections} ->
        {:noreply, state}
    end
  end

  def __handle_info__(
        module,
        _super_fn,
        {:DOWN, _ref, :process, pid, _reason},
        %State{} = state
      ) do
    case Enum.find(state.connections, fn {_id, {c, _ref}} -> c.pid == pid end) do
      {_id, {conn, _ref}} ->
        connections = Map.delete(state.connections, conn.id)

        case module.handle_disconnect(conn, state.agent_state) do
          {:noreply, agent_state} ->
            {:noreply, %{state | connections: connections, agent_state: agent_state}}
        end

      nil ->
        {:noreply, state}
    end
  end

  def __handle_info__(_module, _super_fn, {:a2ui_sync, pid, ref}, %State{} = state) do
    send(pid, {:a2ui_sync_ack, ref})
    {:noreply, state}
  end

  def __handle_info__(_module, super_fn, msg, %State{} = state) do
    case super_fn.(msg, state.agent_state) do
      {:noreply, agent_state} ->
        {:noreply, %{state | agent_state: agent_state}}
    end
  end
end
