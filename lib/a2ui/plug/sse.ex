if Code.ensure_loaded?(Plug) do
  defmodule A2UI.Plug.SSE do
    @moduledoc """
    SSE connection handler for A2UI.

    Streams A2UI protocol messages from an agent to a client as
    Server-Sent Events. Called by `A2UI.Plug` when a client opens
    `GET /sse`.

    ## Event Format

    The first event contains the connection ID for use in JSON-RPC calls:

        id: 0
        data: {"connectionId":"abc123"}

    Subsequent events contain A2UI protocol messages:

        id: 1
        data: {"version":"v0.9","createSurface":{"surfaceId":"main"}}

    Keep-alive comments are sent every 30 seconds:

        : ping

    """

    import Plug.Conn

    alias A2UI.{Connection, Plug.ConnectionRegistry}

    @ping_interval 30_000

    @doc """
    Starts an SSE stream for the given agent.

    Creates a `Connection`, registers it, connects to the agent,
    and enters a blocking receive loop that streams messages as SSE events.
    """
    @spec stream(Plug.Conn.t(), GenServer.server(), atom()) :: Plug.Conn.t()
    def stream(conn, agent, registry \\ ConnectionRegistry) do
      connection = %Connection{
        id: generate_id(),
        transport: A2UI.Transport.SSE,
        ref: self(),
        pid: self()
      }

      ConnectionRegistry.register(connection.id, self(), registry)
      agent_ref = Process.monitor(agent)
      send(agent, {:a2ui_connect, connection})

      conn =
        conn
        |> put_resp_header("content-type", "text/event-stream")
        |> put_resp_header("cache-control", "no-cache")
        |> put_resp_header("connection", "keep-alive")
        |> put_resp_header("x-accel-buffering", "no")
        |> send_chunked(200)

      case send_event(conn, 0, Jason.encode!(%{"connectionId" => connection.id})) do
        {:ok, conn} -> stream_loop(conn, connection, agent, agent_ref, registry, 1)
        {:error, conn} -> cleanup(conn, connection, agent, registry)
      end
    end

    defp stream_loop(conn, connection, agent, agent_ref, registry, seq) do
      receive do
        {:a2ui_deliver, msg} ->
          case A2UI.Protocol.Message.to_json(msg) do
            {:ok, json} ->
              case send_event(conn, seq, json) do
                {:ok, conn} ->
                  stream_loop(conn, connection, agent, agent_ref, registry, seq + 1)

                {:error, conn} ->
                  cleanup(conn, connection, agent, registry)
              end

            {:error, _reason} ->
              stream_loop(conn, connection, agent, agent_ref, registry, seq)
          end

        {:DOWN, ^agent_ref, :process, _pid, _reason} ->
          cleanup(conn, connection, agent, registry)
      after
        @ping_interval ->
          case chunk(conn, ": ping\n\n") do
            {:ok, conn} -> stream_loop(conn, connection, agent, agent_ref, registry, seq)
            {:error, :closed} -> cleanup(conn, connection, agent, registry)
          end
      end
    end

    defp send_event(conn, seq, data) do
      case chunk(conn, "id: #{seq}\ndata: #{data}\n\n") do
        {:ok, conn} -> {:ok, conn}
        {:error, :closed} -> {:error, conn}
      end
    end

    defp cleanup(conn, connection, agent, registry) do
      ConnectionRegistry.unregister(connection.id, registry)
      send(agent, {:a2ui_disconnect, connection})
      conn
    end

    defp generate_id do
      Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
    end
  end
end
