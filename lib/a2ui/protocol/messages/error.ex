defmodule A2UI.Protocol.Messages.Error do
  @moduledoc """
  Represents an error message sent from client to server.

  Used when the client detects a validation failure that the agent
  should be informed about, enabling a self-correction loop.

  ## Fields

  - `code` — error code, e.g. `"VALIDATION_FAILED"`
  - `surface_id` — the surface where the error occurred
  - `path` — JSON Pointer to the problematic field
  - `message` — brief explanation of the failure
  """

  defstruct [:code, :surface_id, :path, :message]

  @type t :: %__MODULE__{
          code: String.t(),
          surface_id: String.t(),
          path: String.t(),
          message: String.t()
        }

  @doc """
  Parses a raw JSON map into an Error struct.
  """
  @spec from_map(map()) :: t()
  def from_map(map) do
    %__MODULE__{
      code: Map.fetch!(map, "code"),
      surface_id: Map.fetch!(map, "surfaceId"),
      path: Map.fetch!(map, "path"),
      message: Map.fetch!(map, "message")
    }
  end

  @doc """
  Converts an Error struct back to a JSON-compatible map.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = msg) do
    %{
      "code" => msg.code,
      "surfaceId" => msg.surface_id,
      "path" => msg.path,
      "message" => msg.message
    }
  end
end
