if Code.ensure_loaded?(A2A.Agent) do
  defmodule A2UI.A2A do
    @moduledoc """
    Adapter that exposes an A2UI agent over the A2A protocol.

    `use A2UI.A2A` generates an `A2A.Agent` that wraps the given
    `A2UI.Agent`, translating between A2A messages and A2UI protocol
    messages. Each A2UI envelope is carried as an `A2A.Part.Data` part.

    ## Example

        defmodule MyApp.A2AAdapter do
          use A2UI.A2A,
            agent: MyApp.UIAgent,
            name: "my-ui-agent",
            description: "Serves UI via A2A"
        end

    Then serve via `A2A.Plug`:

        forward "/a2a", A2A.Plug,
          agent: MyApp.A2AAdapter,
          base_url: "http://localhost:4000/a2a"

    ## Options

    - `:agent` — module name of the `A2UI.Agent` to wrap (required).
      The agent must be running and registered under this name.
    - All other options (`:name`, `:description`, `:version`, `:skills`)
      are forwarded to `use A2A.Agent`.

    ## Protocol Mapping

    - First A2A message in a task triggers `handle_connect` on the A2UI agent
    - Subsequent messages extract `Action` / `Error` from `Part.Data` parts
      and forward them via `handle_action` / `handle_error`
    - A2UI response messages are wrapped as `A2A.Part.Data` and returned
      as `{:input_required, parts}` to keep the task open for more turns
    - Cancelling the A2A task disconnects the A2UI connection
    """

    alias A2UI.Connection
    alias A2UI.Protocol.Message, as: Msg

    @doc false
    defmacro __using__(opts) do
      agent = Keyword.fetch!(opts, :agent)
      a2a_opts = Keyword.drop(opts, [:agent])

      quote do
        use A2A.Agent, unquote(a2a_opts)

        @a2ui_agent unquote(agent)

        @impl A2A.Agent
        def handle_message(message, context) do
          A2UI.A2A.__handle_message__(@a2ui_agent, message, context)
        end

        @impl A2A.Agent
        def handle_cancel(context) do
          A2UI.A2A.__handle_cancel__(context)
        end
      end
    end

    # -- Runtime implementation (called from generated code) --

    @doc false
    @spec __handle_message__(GenServer.server(), A2A.Message.t(), A2A.Agent.context()) ::
            A2A.Agent.reply()
    def __handle_message__(a2ui_agent, message, context) do
      {handler, conn} = get_or_create_handler(a2ui_agent, context)

      case Process.get({:a2ui_handler_state, context.task_id}) do
        :connected ->
          forward_client_messages(a2ui_agent, message, conn)

        _new ->
          send(a2ui_agent, {:a2ui_connect, conn})
          Process.put({:a2ui_handler_state, context.task_id}, :connected)
      end

      sync(a2ui_agent)
      parts = drain_and_wrap(handler)
      {:input_required, parts}
    end

    @doc false
    @spec __handle_cancel__(A2A.Agent.context()) :: :ok
    def __handle_cancel__(context) do
      case Process.get({:a2ui_handler, context.task_id}) do
        {pid, _conn} ->
          Process.unlink(pid)
          Process.exit(pid, :shutdown)
          Process.delete({:a2ui_handler, context.task_id})
          Process.delete({:a2ui_handler_state, context.task_id})

        nil ->
          :ok
      end

      :ok
    end

    # -- Private helpers --

    defp get_or_create_handler(a2ui_agent, context) do
      case Process.get({:a2ui_handler, context.task_id}) do
        {pid, conn} ->
          {pid, conn}

        nil ->
          pid = spawn_link(fn -> handler_loop([]) end)

          conn = %Connection{
            id: "a2a-#{:erlang.unique_integer([:positive])}",
            transport: A2UI.A2A.Delivery,
            ref: pid,
            pid: pid
          }

          # Monitor the A2UI agent so we can detect shutdown
          Process.monitor(Process.whereis(a2ui_agent) || a2ui_agent)

          Process.put({:a2ui_handler, context.task_id}, {pid, conn})
          {pid, conn}
      end
    end

    defp forward_client_messages(a2ui_agent, message, conn) do
      message.parts
      |> Enum.filter(&match?(%A2A.Part.Data{}, &1))
      |> Enum.each(fn %A2A.Part.Data{data: data} ->
        case Msg.from_map(data) do
          {:ok, %A2UI.Protocol.Messages.Action{} = action} ->
            send(a2ui_agent, {:a2ui_action, action, %{connection: conn}})

          {:ok, %A2UI.Protocol.Messages.Error{} = error} ->
            send(a2ui_agent, {:a2ui_error, error, %{connection: conn}})

          _ ->
            :skip
        end
      end)
    end

    defp sync(a2ui_agent) do
      ref = make_ref()
      send(a2ui_agent, {:a2ui_sync, self(), ref})

      receive do
        {:a2ui_sync_ack, ^ref} -> :ok
      after
        5_000 -> :timeout
      end
    end

    defp drain_and_wrap(handler) do
      ref = make_ref()
      send(handler, {:drain, self(), ref})

      receive do
        {^ref, messages} ->
          Enum.map(messages, fn msg ->
            A2A.Part.Data.new(Msg.to_map(msg))
          end)
      after
        5_000 -> []
      end
    end

    defp handler_loop(buffer) do
      receive do
        {:a2ui_deliver, msg} ->
          handler_loop([msg | buffer])

        {:drain, caller, ref} ->
          send(caller, {ref, Enum.reverse(buffer)})
          handler_loop([])
      end
    end
  end

  defmodule A2UI.A2A.Delivery do
    @moduledoc false
    @behaviour A2UI.Transport

    @impl true
    def deliver_message(handler_pid, message) do
      send(handler_pid, {:a2ui_deliver, message})
      :ok
    end
  end
end
