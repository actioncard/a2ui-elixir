defmodule A2UI.Protocol.Message do
  @moduledoc """
  Union type and dispatcher for A2UI protocol messages.

  Dispatches raw JSON maps to the appropriate message struct based on
  the message type key.
  """

  alias A2UI.Protocol.Messages.{
    Action,
    CreateSurface,
    DeleteSurface,
    UpdateComponents,
    UpdateDataModel
  }

  @type t ::
          CreateSurface.t()
          | UpdateComponents.t()
          | UpdateDataModel.t()
          | DeleteSurface.t()
          | Action.t()

  @doc """
  Parses a decoded JSON map into the appropriate message struct.

  Dispatches based on the presence of known message type keys.
  Server→client messages must include `"version": "v0.9"`.

  ## Examples

      iex> A2UI.Protocol.Message.from_map(%{"version" => "v0.9", "createSurface" => %{"surfaceId" => "main", "catalogId" => "test"}})
      {:ok, %A2UI.Protocol.Messages.CreateSurface{surface_id: "main", catalog_id: "test"}}
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(%{"version" => "v0.9", "createSurface" => inner}) do
    {:ok, CreateSurface.from_map(inner)}
  end

  def from_map(%{"version" => "v0.9", "updateComponents" => inner}) do
    {:ok, UpdateComponents.from_map(inner)}
  end

  def from_map(%{"version" => "v0.9", "updateDataModel" => inner}) do
    {:ok, UpdateDataModel.from_map(inner)}
  end

  def from_map(%{"version" => "v0.9", "deleteSurface" => inner}) do
    {:ok, DeleteSurface.from_map(inner)}
  end

  # Client → server action (no version field)
  def from_map(%{"name" => _, "surfaceId" => _} = map) do
    {:ok, Action.from_map(map)}
  end

  def from_map(%{"version" => version}) do
    {:error, "unsupported protocol version: #{version}"}
  end

  def from_map(_) do
    {:error, "unknown message format"}
  end

  @doc """
  Parses a JSON string into a message struct.
  """
  @spec from_json(String.t()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, map} ->
        from_map(map)

      {:error, %Jason.DecodeError{} = err} ->
        {:error, "JSON decode error: #{Exception.message(err)}"}
    end
  end

  @doc """
  Converts a message struct to a JSON-compatible map.

  Server→client messages are wrapped with `"version": "v0.9"`.
  Action (client→server) is returned without a version wrapper.
  """
  @spec to_map(t()) :: map()
  def to_map(%CreateSurface{} = msg) do
    wrap("createSurface", CreateSurface.to_map(msg))
  end

  def to_map(%UpdateComponents{} = msg) do
    wrap("updateComponents", UpdateComponents.to_map(msg))
  end

  def to_map(%UpdateDataModel{} = msg) do
    wrap("updateDataModel", UpdateDataModel.to_map(msg))
  end

  def to_map(%DeleteSurface{} = msg) do
    wrap("deleteSurface", DeleteSurface.to_map(msg))
  end

  def to_map(%Action{} = msg), do: Action.to_map(msg)

  @doc """
  Converts a message struct to a JSON string.

  Returns `{:ok, json}` or `{:error, reason}`.
  """
  @spec to_json(t()) :: {:ok, String.t()} | {:error, Jason.EncodeError.t()}
  def to_json(msg) do
    msg |> to_map() |> Jason.encode()
  end

  defp wrap(key, inner), do: %{"version" => "v0.9", key => inner}
end
