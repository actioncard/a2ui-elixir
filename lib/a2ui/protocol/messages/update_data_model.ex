defmodule A2UI.Protocol.Messages.UpdateDataModel do
  @moduledoc """
  Represents an `updateDataModel` message from the A2UI protocol.
  """

  defstruct [:surface_id, path: "/", value: nil, has_value: false]

  @type t :: %__MODULE__{
          surface_id: String.t(),
          path: String.t(),
          value: any(),
          has_value: boolean()
        }

  @doc """
  Parses a raw JSON map (the inner `updateDataModel` object) into a struct.

  When `"value"` is present in the map, `has_value` is set to `true`.
  Omitting `"value"` means "delete at path" per the spec.
  """
  @spec from_map(map()) :: t()
  def from_map(map) do
    %__MODULE__{
      surface_id: Map.fetch!(map, "surfaceId"),
      path: Map.get(map, "path", "/"),
      value: Map.get(map, "value"),
      has_value: Map.has_key?(map, "value")
    }
  end
end
