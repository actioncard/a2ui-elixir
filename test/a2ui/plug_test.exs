defmodule A2UI.PlugTest do
  use ExUnit.Case, async: true

  alias A2UI.Plug, as: A2UIPlug

  setup do
    opts = A2UIPlug.init(agent: self())
    %{opts: opts}
  end

  test "GET /sse does not 404 (route matches SSE handler)" do
    # Plug.Test doesn't support chunked SSE responses, so we verify
    # route matching indirectly: POST /sse returns 405, proving the
    # path is recognized. Full SSE streaming tested in plug/sse_test.exs.
    opts = A2UIPlug.init(agent: self())
    conn = A2UIPlug.call(Plug.Test.conn(:post, "/sse"), opts)
    assert conn.status == 405
    assert Plug.Conn.get_resp_header(conn, "allow") == ["GET"]
  end

  test "POST /rpc returns JSON-RPC response", %{opts: opts} do
    body =
      Jason.encode!(%{"jsonrpc" => "2.0", "method" => "a2ui.unknown", "params" => %{}, "id" => 1})

    conn =
      Plug.Test.conn(:post, "/rpc", body)
      |> Plug.Conn.put_req_header("content-type", "application/json")

    conn = A2UIPlug.call(conn, opts)

    assert conn.status == 200
    response = Jason.decode!(conn.resp_body)
    assert response["error"]["code"] == -32_601
  end

  test "GET /rpc returns 405", %{opts: opts} do
    conn = A2UIPlug.call(Plug.Test.conn(:get, "/rpc"), opts)
    assert conn.status == 405
  end

  test "unknown path returns 404", %{opts: opts} do
    conn = A2UIPlug.call(Plug.Test.conn(:get, "/unknown"), opts)
    assert conn.status == 404
  end

  test "custom paths" do
    opts = A2UIPlug.init(agent: self(), sse_path: ["events"], rpc_path: ["api"])

    conn =
      Plug.Test.conn(
        :post,
        "/api",
        Jason.encode!(%{
          "jsonrpc" => "2.0",
          "method" => "a2ui.unknown",
          "params" => %{},
          "id" => 1
        })
      )
      |> Plug.Conn.put_req_header("content-type", "application/json")

    conn = A2UIPlug.call(conn, opts)
    assert conn.status == 200
  end
end
