defmodule A2UI.Connection do
  @moduledoc """
  Opaque handle representing a connected client.

  A connection is created by a transport when a client connects to an agent.
  The agent receives the connection in its `handle_connect/2` callback and
  passes it to `A2UI.Agent.send_message/2` to deliver messages back.

  ## Fields

  - `:id` — unique connection identifier (string)
  - `:transport` — module implementing `A2UI.Transport` (used for message delivery)
  - `:ref` — transport-specific reference passed to `deliver_message/2`
  - `:pid` — process to monitor for disconnect detection
  """

  defstruct [:id, :transport, :ref, :pid]

  @type t :: %__MODULE__{
          id: String.t(),
          transport: module(),
          ref: term(),
          pid: pid()
        }

  @doc """
  Creates a local connection for the calling process.

  Convenience for tests and local transports. Sets the transport to
  `A2UI.Transport.Local` and uses the given pid as both `:ref` and `:pid`.
  """
  @spec local(pid()) :: t()
  def local(pid \\ self()) do
    %__MODULE__{
      id: "local-#{:erlang.unique_integer([:positive])}",
      transport: A2UI.Transport.Local,
      ref: pid,
      pid: pid
    }
  end
end
