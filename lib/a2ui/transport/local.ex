defmodule A2UI.Transport.Local do
  @moduledoc """
  In-process transport for A2UI.

  Uses Erlang message passing to communicate between a LiveView and a local agent process.
  The agent sends protocol messages back as `{:a2ui_message, parsed_struct}`.
  """

  @behaviour A2UI.Transport

  defstruct [:agent, :liveview]

  @type t :: %__MODULE__{
          agent: pid(),
          liveview: pid()
        }

  @impl true
  def connect(opts) do
    agent = Keyword.fetch!(opts, :agent)
    liveview = self()
    send(agent, {:a2ui_connect, liveview})
    {:ok, %__MODULE__{agent: agent, liveview: liveview}}
  end

  @impl true
  def send_action(%__MODULE__{agent: agent}, action, metadata) do
    send(agent, {:a2ui_action, action, metadata})
    :ok
  end

  @impl true
  def send_error(%__MODULE__{agent: agent}, error, metadata) do
    send(agent, {:a2ui_error, error, metadata})
    :ok
  end

  @impl true
  def disconnect(%__MODULE__{agent: agent, liveview: liveview}) do
    send(agent, {:a2ui_disconnect, liveview})
    :ok
  end
end
