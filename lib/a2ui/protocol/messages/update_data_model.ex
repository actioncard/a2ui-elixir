defmodule A2UI.Protocol.Messages.UpdateDataModel do
  @moduledoc """
  Represents an `updateDataModel` message from the A2UI protocol.
  """

  defstruct [:surface_id, path: "/", value: nil]

  @type t :: %__MODULE__{
          surface_id: String.t(),
          path: String.t(),
          value: any()
        }

  @doc """
  Parses a raw JSON map (the inner `updateDataModel` object) into a struct.
  """
  @spec from_map(map()) :: t()
  def from_map(map) do
    %__MODULE__{
      surface_id: Map.fetch!(map, "surfaceId"),
      path: Map.get(map, "path", "/"),
      value: Map.get(map, "value")
    }
  end
end
