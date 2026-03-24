if Code.ensure_loaded?(A2A.Client) do
  defmodule A2UI.Transport.A2A do
    @moduledoc """
    A2A client transport for A2UI.

    Connects a LiveView to a remote A2UI agent served via `A2UI.A2A`
    over the A2A protocol (JSON-RPC + HTTP).

    ## Example

        # In your LiveView mount:
        {:ok, transport} = A2UI.Transport.A2A.connect(
          url: "http://remote-agent:4000/a2a"
        )

    The transport delivers messages to the calling process (the
    LiveView) as `{:a2ui_message, msg}`, matching the local transport
    behaviour.

    ## Options for `connect/1`

    - `:url` — URL of the remote A2A agent (required unless `:client` given)
    - `:client` — pre-built `A2A.Client` struct
    - `:context_id` — A2A context ID for session continuity
    """

    @behaviour A2UI.Transport

    alias A2UI.Connection
    alias A2UI.Protocol.Message, as: Msg

    defstruct [:client, :handler, :connection]

    @type t :: %__MODULE__{
            client: A2A.Client.t(),
            handler: pid(),
            connection: Connection.t()
          }

    @impl true
    @spec connect(keyword()) :: {:ok, t()} | {:error, any()}
    def connect(opts) do
      client = opts[:client] || A2A.Client.new(Keyword.fetch!(opts, :url))
      liveview = self()
      context_id = opts[:context_id]

      handler = spawn_link(fn -> init_handler(client, liveview, context_id) end)

      conn = %Connection{
        id: "a2a-#{:erlang.unique_integer([:positive])}",
        transport: __MODULE__,
        ref: liveview,
        pid: handler
      }

      {:ok, %__MODULE__{client: client, handler: handler, connection: conn}}
    end

    @impl true
    @spec deliver_message(pid(), struct()) :: :ok | {:error, any()}
    def deliver_message(liveview_pid, message) do
      send(liveview_pid, {:a2ui_message, message})
      :ok
    end

    @impl true
    @spec send_action(t(), A2UI.Protocol.Messages.Action.t(), map()) :: :ok | {:error, any()}
    def send_action(%__MODULE__{handler: handler}, action, _metadata) do
      action_map = A2UI.Protocol.Messages.Action.to_map(action)
      msg = A2A.Message.new_user([A2A.Part.Data.new(action_map)])
      send(handler, {:a2a_send, msg})
      :ok
    end

    @impl true
    @spec send_error(t(), A2UI.Protocol.Messages.Error.t(), map()) :: :ok | {:error, any()}
    def send_error(%__MODULE__{handler: handler}, error, _metadata) do
      error_map = A2UI.Protocol.Messages.Error.to_map(error)
      msg = A2A.Message.new_user([A2A.Part.Data.new(error_map)])
      send(handler, {:a2a_send, msg})
      :ok
    end

    @impl true
    @spec disconnect(t()) :: :ok
    def disconnect(%__MODULE__{handler: handler}) do
      send(handler, :stop)
      :ok
    end

    # -- Handler process --

    defp init_handler(client, liveview, context_id) do
      initial = A2A.Message.new_user([A2A.Part.Data.new(%{"a2ui" => "connect"})])
      opts = if context_id, do: [context_id: context_id], else: []

      case A2A.Client.send_message(client, initial, opts) do
        {:ok, task} ->
          deliver_parts(task, liveview)
          handler_loop(client, liveview, task.id)

        {:error, reason} ->
          send(liveview, {:a2ui_transport_error, reason})
      end
    end

    defp handler_loop(client, liveview, task_id) do
      receive do
        {:a2a_send, message} ->
          case A2A.Client.send_message(client, message, task_id: task_id) do
            {:ok, task} ->
              deliver_parts(task, liveview)
              handler_loop(client, liveview, task.id)

            {:error, reason} ->
              send(liveview, {:a2ui_transport_error, reason})
              handler_loop(client, liveview, task_id)
          end

        :stop ->
          A2A.Client.cancel_task(client, task_id)
          :ok
      end
    end

    defp deliver_parts(task, liveview) do
      parts =
        case task.status do
          %{message: %A2A.Message{parts: parts}} -> parts
          _ -> []
        end

      parts
      |> Enum.filter(&match?(%A2A.Part.Data{}, &1))
      |> Enum.each(fn %A2A.Part.Data{data: data} ->
        case Msg.from_map(data) do
          {:ok, msg} -> send(liveview, {:a2ui_message, msg})
          {:error, _} -> :skip
        end
      end)
    end
  end
end
