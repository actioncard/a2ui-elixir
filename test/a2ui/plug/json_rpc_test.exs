defmodule A2UI.Plug.JSONRPCTest do
  use ExUnit.Case, async: true

  alias A2UI.Plug.{ConnectionRegistry, JSONRPC}
  alias A2UI.Protocol.Messages.Action

  setup do
    table = :"registry_#{:erlang.unique_integer([:positive])}"
    ConnectionRegistry.ensure_started(table)
    %{table: table}
  end

  defp json_rpc_conn(body) do
    Plug.Test.conn(:post, "/rpc", Jason.encode!(body))
    |> Plug.Conn.put_req_header("content-type", "application/json")
  end

  defp decode_response(conn) do
    Jason.decode!(conn.resp_body)
  end

  describe "a2ui.action" do
    test "routes action to agent", %{table: table} do
      agent = self()
      ConnectionRegistry.register("test-conn", self(), table)

      body = %{
        "jsonrpc" => "2.0",
        "method" => "a2ui.action",
        "params" => %{
          "connectionId" => "test-conn",
          "action" => %{
            "name" => "submit",
            "surfaceId" => "main",
            "sourceComponentId" => "btn1",
            "timestamp" => "2026-01-01T00:00:00Z",
            "context" => %{"key" => "value"}
          }
        },
        "id" => 1
      }

      conn = JSONRPC.handle(json_rpc_conn(body), agent, table)

      assert conn.status == 200
      response = decode_response(conn)
      assert response["jsonrpc"] == "2.0"
      assert response["result"] == %{"status" => "ok"}
      assert response["id"] == 1

      assert_received {:a2ui_action, %Action{name: "submit", surface_id: "main"}, metadata}
      assert metadata.connection.id == "test-conn"
    end

    test "returns error for unknown connection", %{table: table} do
      body = %{
        "jsonrpc" => "2.0",
        "method" => "a2ui.action",
        "params" => %{
          "connectionId" => "nonexistent",
          "action" => %{"name" => "submit", "surfaceId" => "main", "sourceComponentId" => "btn"}
        },
        "id" => 2
      }

      conn = JSONRPC.handle(json_rpc_conn(body), self(), table)

      response = decode_response(conn)
      assert response["error"]["code"] == -32_001
      assert response["error"]["message"] == "Connection not found"
    end

    test "returns error for missing connectionId", %{table: table} do
      body = %{
        "jsonrpc" => "2.0",
        "method" => "a2ui.action",
        "params" => %{
          "action" => %{"name" => "submit", "surfaceId" => "main", "sourceComponentId" => "btn"}
        },
        "id" => 3
      }

      conn = JSONRPC.handle(json_rpc_conn(body), self(), table)

      response = decode_response(conn)
      assert response["error"]["code"] == -32_602
    end
  end

  describe "a2ui.error" do
    test "routes error to agent", %{table: table} do
      agent = self()
      ConnectionRegistry.register("test-conn", self(), table)

      body = %{
        "jsonrpc" => "2.0",
        "method" => "a2ui.error",
        "params" => %{
          "connectionId" => "test-conn",
          "error" => %{
            "code" => "VALIDATION_FAILED",
            "surfaceId" => "main",
            "path" => "/name",
            "message" => "Name is required"
          }
        },
        "id" => 4
      }

      conn = JSONRPC.handle(json_rpc_conn(body), agent, table)

      response = decode_response(conn)
      assert response["result"] == %{"status" => "ok"}

      assert_received {:a2ui_error, error, metadata}
      assert error.code == "VALIDATION_FAILED"
      assert metadata.connection.id == "test-conn"
    end
  end

  describe "unknown method" do
    test "returns method not found", %{table: table} do
      body = %{
        "jsonrpc" => "2.0",
        "method" => "a2ui.unknown",
        "params" => %{},
        "id" => 5
      }

      conn = JSONRPC.handle(json_rpc_conn(body), self(), table)

      response = decode_response(conn)
      assert response["error"]["code"] == -32_601
      assert response["error"]["message"] == "Method not found"
    end
  end

  describe "invalid request" do
    test "returns error for non-JSON body", %{table: table} do
      conn =
        Plug.Test.conn(:post, "/rpc", "not json")
        |> Plug.Conn.put_req_header("content-type", "application/json")

      conn = JSONRPC.handle(conn, self(), table)

      response = decode_response(conn)
      assert response["error"]["code"] == -32_700
    end

    test "returns error for missing jsonrpc fields", %{table: table} do
      body = %{"foo" => "bar"}

      conn = JSONRPC.handle(json_rpc_conn(body), self(), table)

      response = decode_response(conn)
      assert response["error"]["code"] == -32_600
    end
  end
end
