defmodule A2UI.Protocol.Messages.UpdateComponents do
  @moduledoc """
  Represents an `updateComponents` message from the A2UI protocol.
  """

  alias A2UI.Component

  defstruct [:surface_id, components: []]

  @type t :: %__MODULE__{
          surface_id: String.t(),
          components: [Component.t()]
        }

  @doc """
  Parses a raw JSON map (the inner `updateComponents` object) into a struct.
  """
  @spec from_map(map()) :: t()
  def from_map(map) do
    components =
      map
      |> Map.get("components", [])
      |> Enum.map(&Component.from_map/1)

    %__MODULE__{
      surface_id: Map.fetch!(map, "surfaceId"),
      components: components
    }
  end
end
