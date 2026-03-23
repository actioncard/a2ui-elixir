if Code.ensure_loaded?(Plug) do
  defmodule A2UI.Plug.JSONRPC do
    @moduledoc """
    JSON-RPC 2.0 handler for A2UI.

    Routes client actions and errors to the agent via the SSE handler
    process. Called by `A2UI.Plug` when a client sends `POST /rpc`.

    ## Methods

    - `a2ui.action` — send a user action to the agent
    - `a2ui.error` — send a validation error to the agent

    ## Request Format

        {"jsonrpc":"2.0","method":"a2ui.action","params":{"connectionId":"abc123","action":{...}},"id":1}

    ## Response Format

        {"jsonrpc":"2.0","result":{"status":"ok"},"id":1}

    """

    import Plug.Conn

    alias A2UI.{Connection, Plug.ConnectionRegistry}
    alias A2UI.Protocol.Messages.{Action, Error}

    @doc """
    Handles a JSON-RPC POST request.
    """
    @spec handle(Plug.Conn.t(), GenServer.server(), atom()) :: Plug.Conn.t()
    def handle(conn, agent, registry \\ ConnectionRegistry) do
      case read_json_body(conn) do
        {:ok, request, conn} ->
          dispatch(conn, request, agent, registry)

        {:error, :parse_error, conn} ->
          send_json(conn, error_response(nil, -32_700, "Parse error"))

        {:error, :body_too_large, conn} ->
          send_json(conn, error_response(nil, -32_700, "Body too large"))
      end
    end

    defp dispatch(
           conn,
           %{"jsonrpc" => "2.0", "method" => method, "params" => params, "id" => id},
           agent,
           registry
         ) do
      case handle_method(method, params, agent, registry) do
        {:ok, result} ->
          send_json(conn, %{"jsonrpc" => "2.0", "result" => result, "id" => id})

        {:error, code, message} ->
          send_json(conn, error_response(id, code, message))
      end
    end

    defp dispatch(conn, %{"id" => id}, _agent, _registry) do
      send_json(conn, error_response(id, -32_600, "Invalid Request"))
    end

    defp dispatch(conn, _request, _agent, _registry) do
      send_json(conn, error_response(nil, -32_600, "Invalid Request"))
    end

    defp handle_method("a2ui.action", params, agent, registry) when is_map(params) do
      with {:ok, conn_id} <- fetch_param(params, "connectionId"),
           {:ok, action_data} <- fetch_param(params, "action"),
           {:ok, handler_pid} <- ConnectionRegistry.lookup(conn_id, registry),
           {:ok, action} <- build_action(action_data) do
        connection = build_connection(conn_id, handler_pid)
        send(agent, {:a2ui_action, action, %{connection: connection}})
        {:ok, %{"status" => "ok"}}
      else
        {:error, :not_found} -> {:error, -32_001, "Connection not found"}
        {:error, :missing_param} -> {:error, -32_602, "Missing required parameter"}
        {:error, reason} -> {:error, -32_602, "Invalid params: #{inspect(reason)}"}
      end
    end

    defp handle_method("a2ui.error", params, agent, registry) when is_map(params) do
      with {:ok, conn_id} <- fetch_param(params, "connectionId"),
           {:ok, error_data} <- fetch_param(params, "error"),
           {:ok, handler_pid} <- ConnectionRegistry.lookup(conn_id, registry),
           {:ok, error} <- build_error(error_data) do
        connection = build_connection(conn_id, handler_pid)
        send(agent, {:a2ui_error, error, %{connection: connection}})
        {:ok, %{"status" => "ok"}}
      else
        {:error, :not_found} -> {:error, -32_001, "Connection not found"}
        {:error, :missing_param} -> {:error, -32_602, "Missing required parameter"}
        {:error, reason} -> {:error, -32_602, "Invalid params: #{inspect(reason)}"}
      end
    end

    defp handle_method(_method, params, _agent, _registry) when not is_map(params) do
      {:error, -32_602, "params must be an object"}
    end

    defp handle_method(_method, _params, _agent, _registry) do
      {:error, -32_601, "Method not found"}
    end

    defp build_connection(conn_id, handler_pid) do
      %Connection{
        id: conn_id,
        transport: A2UI.Transport.SSE,
        ref: handler_pid,
        pid: handler_pid
      }
    end

    defp build_action(%{"name" => name} = data) when is_binary(name) do
      {:ok,
       %Action{
         name: name,
         surface_id: data["surfaceId"],
         source_component_id: data["sourceComponentId"],
         timestamp: data["timestamp"],
         context: data["context"] || %{}
       }}
    end

    defp build_action(_), do: {:error, :invalid_action}

    defp build_error(%{"code" => code} = data) when is_binary(code) do
      {:ok,
       %Error{
         code: code,
         surface_id: data["surfaceId"],
         path: data["path"],
         message: data["message"]
       }}
    end

    defp build_error(_), do: {:error, :invalid_error}

    defp fetch_param(params, key) do
      case Map.fetch(params, key) do
        {:ok, value} -> {:ok, value}
        :error -> {:error, :missing_param}
      end
    end

    defp read_json_body(%{body_params: %Plug.Conn.Unfetched{}} = conn) do
      case read_body(conn) do
        {:ok, body, conn} ->
          case Jason.decode(body) do
            {:ok, decoded} -> {:ok, decoded, conn}
            {:error, _} -> {:error, :parse_error, conn}
          end

        {:more, _partial, conn} ->
          {:error, :body_too_large, conn}
      end
    end

    defp read_json_body(%{body_params: %{} = params} = conn) do
      {:ok, params, conn}
    end

    defp error_response(id, code, message) do
      %{"jsonrpc" => "2.0", "error" => %{"code" => code, "message" => message}, "id" => id}
    end

    defp send_json(conn, response) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(response))
    end
  end
end
