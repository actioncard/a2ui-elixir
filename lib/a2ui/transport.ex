defmodule A2UI.Transport do
  @moduledoc """
  Behaviour for A2UI message transport.

  A transport handles bidirectional communication between a client (LiveView
  or external) and an agent:

  - **Client → Agent**: `connect/1`, `send_action/3`, `send_error/3`, `disconnect/1`
  - **Agent → Client**: `deliver_message/2`

  On `connect/1`, the transport creates an `A2UI.Connection` struct and
  registers with the agent. The agent dispatches messages back through
  `deliver_message/2` using the connection's transport module and ref.

  ## Dispatch Helpers

  Instead of calling a specific transport module directly, you can use
  the dispatch functions on this module:

      A2UI.Transport.send_action(transport, action, metadata)

  These dispatch to the correct implementation based on the transport struct.
  """

  @type t :: struct()

  # -- Client → Agent callbacks (optional — only Local implements these) --

  @callback connect(opts :: keyword()) :: {:ok, t()} | {:error, any()}
  @callback send_action(t(), A2UI.Protocol.Messages.Action.t(), metadata :: map()) ::
              :ok | {:error, any()}
  @callback send_error(t(), A2UI.Protocol.Messages.Error.t(), metadata :: map()) ::
              :ok | {:error, any()}
  @callback disconnect(t()) :: :ok

  @optional_callbacks connect: 1, send_action: 3, send_error: 3, disconnect: 1

  # -- Agent → Client callback --

  @doc """
  Delivers an A2UI protocol message to the connected client.

  Called by `A2UI.Agent.send_message/2` using the connection's transport
  module and ref. The `ref` argument is transport-specific — for Local
  transport it is the LiveView pid; for SSE it is the handler process pid.
  """
  @callback deliver_message(ref :: term(), message :: struct()) :: :ok | {:error, any()}

  # -- Dispatch helpers --

  @doc """
  Sends an action through the transport. Dispatches based on the struct module.
  """
  @spec send_action(t(), A2UI.Protocol.Messages.Action.t(), map()) :: :ok | {:error, any()}
  def send_action(%mod{} = transport, action, metadata) do
    mod.send_action(transport, action, metadata)
  end

  @doc """
  Sends an error through the transport. Dispatches based on the struct module.
  """
  @spec send_error(t(), A2UI.Protocol.Messages.Error.t(), map()) :: :ok | {:error, any()}
  def send_error(%mod{} = transport, error, metadata) do
    mod.send_error(transport, error, metadata)
  end

  @doc """
  Disconnects the transport. Dispatches based on the struct module.
  """
  @spec disconnect(t()) :: :ok
  def disconnect(%mod{} = transport) do
    mod.disconnect(transport)
  end
end
