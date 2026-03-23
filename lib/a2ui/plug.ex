if Code.ensure_loaded?(Plug) do
  defmodule A2UI.Plug do
    @moduledoc """
    Plug for serving A2UI agents over HTTP.

    Provides SSE streaming (server→client) and JSON-RPC 2.0 (client→server)
    endpoints. Works standalone with Bandit or mounted inside Phoenix via
    `forward`.

    ## Usage

        # In a Phoenix router:
        forward "/a2ui", A2UI.Plug, agent: MyAgent

        # Standalone with Bandit:
        Bandit.start_link(plug: {A2UI.Plug, agent: MyAgent})

    ## Options

    - `:agent` — GenServer name or pid of the agent (required)
    - `:sse_path` — path segments for the SSE endpoint (default: `["sse"]`)
    - `:rpc_path` — path segments for the JSON-RPC endpoint (default: `["rpc"]`)

    ## Endpoints

    - `GET /sse` — opens an SSE stream. The first event contains a
      `connectionId` the client must include in subsequent JSON-RPC calls.
    - `POST /rpc` — accepts JSON-RPC 2.0 requests. Methods:
      `a2ui.action`, `a2ui.error`.

    ## CORS

    This plug does not set CORS headers. If your SSE/RPC endpoints are
    accessed from a different origin, add a CORS plug (e.g. `cors_plug`)
    upstream in your pipeline.

    ## Security

    The `connectionId` returned by the SSE endpoint acts as a bearer
    token — any client that knows the ID can send JSON-RPC requests for
    that session. The ID is a 128-bit cryptographically random value, so
    brute-force guessing is infeasible. To protect against leakage:

    - Serve SSE and RPC endpoints over HTTPS only
    - Do not log `connectionId` values at non-debug levels
    - Add application-layer authentication upstream if stricter
      session isolation is required
    """

    @behaviour Plug

    import Plug.Conn

    # -- Plug callbacks --------------------------------------------------------

    @impl Plug
    @spec init(keyword()) :: map()
    def init(opts) do
      %{
        agent: Keyword.fetch!(opts, :agent),
        sse_path: Keyword.get(opts, :sse_path, ["sse"]),
        rpc_path: Keyword.get(opts, :rpc_path, ["rpc"])
      }
    end

    @impl Plug
    @spec call(Plug.Conn.t(), map()) :: Plug.Conn.t()
    def call(%{method: "GET", path_info: path} = conn, %{sse_path: path} = opts) do
      # Lazy-start the registry on first request. Cannot live in init/1
      # because Phoenix calls it at compile time. See ConnectionRegistry
      # moduledoc "Design note" for full rationale.
      A2UI.Plug.ConnectionRegistry.ensure_started()
      A2UI.Plug.SSE.stream(conn, opts.agent)
    end

    def call(%{method: "POST", path_info: path} = conn, %{rpc_path: path} = opts) do
      A2UI.Plug.ConnectionRegistry.ensure_started()
      A2UI.Plug.JSONRPC.handle(conn, opts.agent)
    end

    def call(%{path_info: path} = conn, %{sse_path: path}) do
      conn
      |> put_resp_header("allow", "GET")
      |> send_resp(405, "Method Not Allowed")
    end

    def call(%{path_info: path} = conn, %{rpc_path: path}) do
      conn
      |> put_resp_header("allow", "POST")
      |> send_resp(405, "Method Not Allowed")
    end

    def call(conn, _opts) do
      send_resp(conn, 404, "Not Found")
    end
  end
end
