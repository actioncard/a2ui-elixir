defmodule A2UI.Protocol.Messages.CreateSurface do
  @moduledoc """
  Represents a `createSurface` message from the A2UI protocol.
  """

  defstruct [:surface_id, :catalog_id, theme: %{}, send_data_model: false]

  @type t :: %__MODULE__{
          surface_id: String.t(),
          catalog_id: String.t(),
          theme: map(),
          send_data_model: boolean()
        }

  @doc """
  Parses a raw JSON map (the inner `createSurface` object) into a struct.
  """
  @spec from_map(map()) :: t()
  def from_map(map) do
    theme = Map.get(map, "theme", %{})

    %__MODULE__{
      surface_id: Map.fetch!(map, "surfaceId"),
      catalog_id: Map.fetch!(map, "catalogId"),
      theme: %{
        primary_color: theme["primaryColor"],
        icon_url: theme["iconUrl"],
        agent_display_name: theme["agentDisplayName"]
      },
      send_data_model: Map.get(map, "sendDataModel", false)
    }
  end
end
