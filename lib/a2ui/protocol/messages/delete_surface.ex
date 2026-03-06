defmodule A2UI.Protocol.Messages.DeleteSurface do
  @moduledoc """
  Represents a `deleteSurface` message from the A2UI protocol.
  """

  defstruct [:surface_id]

  @type t :: %__MODULE__{
          surface_id: String.t()
        }

  @doc """
  Parses a raw JSON map (the inner `deleteSurface` object) into a struct.
  """
  @spec from_map(map()) :: t()
  def from_map(map) do
    %__MODULE__{
      surface_id: Map.fetch!(map, "surfaceId")
    }
  end
end
