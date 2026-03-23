defmodule A2UI.Transport.Local do
  @moduledoc """
  In-process transport for A2UI.

  Uses Erlang message passing to communicate between a LiveView and a local
  agent process. Creates an `A2UI.Connection` on connect and injects it into
  metadata so the agent can route responses back.
  """

  @behaviour A2UI.Transport

  defstruct [:agent, :connection]

  @type t :: %__MODULE__{
          agent: pid() | atom(),
          connection: A2UI.Connection.t()
        }

  @impl true
  def connect(opts) do
    agent = Keyword.fetch!(opts, :agent)
    conn = A2UI.Connection.local(self())
    send(agent, {:a2ui_connect, conn})
    {:ok, %__MODULE__{agent: agent, connection: conn}}
  end

  @impl true
  def deliver_message(liveview_pid, message) do
    send(liveview_pid, {:a2ui_message, message})
    :ok
  end

  @impl true
  def send_action(%__MODULE__{agent: agent, connection: conn}, action, metadata) do
    send(agent, {:a2ui_action, action, Map.put(metadata, :connection, conn)})
    :ok
  end

  @impl true
  def send_error(%__MODULE__{agent: agent, connection: conn}, error, metadata) do
    send(agent, {:a2ui_error, error, Map.put(metadata, :connection, conn)})
    :ok
  end

  @impl true
  def disconnect(%__MODULE__{agent: agent, connection: conn}) do
    send(agent, {:a2ui_disconnect, conn})
    :ok
  end
end
