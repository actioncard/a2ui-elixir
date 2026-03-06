defmodule A2UI.Transport do
  @moduledoc """
  Behaviour for A2UI message transport.

  A transport connects a LiveView to a message source (agent).
  On `connect/1`, the transport begins delivering `{:a2ui_message, msg}`
  to the calling process. `send_action/3` sends actions back to the agent.
  """

  @type t :: struct()

  @callback connect(opts :: keyword()) :: {:ok, t()} | {:error, any()}
  @callback send_action(t(), A2UI.Protocol.Messages.Action.t(), metadata :: map()) ::
              :ok | {:error, any()}
  @callback disconnect(t()) :: :ok
end
