defmodule A2UI.Protocol.Messages.Action do
  @moduledoc """
  Represents an action message sent from client to server.
  """

  defstruct [:name, :surface_id, :source_component_id, :timestamp, context: %{}]

  @type t :: %__MODULE__{
          name: String.t(),
          surface_id: String.t(),
          source_component_id: String.t(),
          timestamp: String.t(),
          context: map()
        }

  @doc """
  Parses a raw JSON map into an Action struct.
  """
  @spec from_map(map()) :: t()
  def from_map(map) do
    %__MODULE__{
      name: Map.fetch!(map, "name"),
      surface_id: Map.fetch!(map, "surfaceId"),
      source_component_id: Map.fetch!(map, "sourceComponentId"),
      timestamp: Map.get(map, "timestamp"),
      context: Map.get(map, "context", %{})
    }
  end
end
