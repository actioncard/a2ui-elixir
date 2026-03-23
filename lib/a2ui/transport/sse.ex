defmodule A2UI.Transport.SSE do
  @moduledoc """
  SSE transport for A2UI.

  Delivers messages to an SSE handler process which streams them to the
  client as Server-Sent Events. Used by `A2UI.Plug.SSE` — not intended
  for direct use.
  """

  @behaviour A2UI.Transport

  @impl true
  def deliver_message(handler_pid, message) do
    send(handler_pid, {:a2ui_deliver, message})
    :ok
  end
end
