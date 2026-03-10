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

  @doc """
  Converts a CreateSurface struct back to a JSON-compatible map (inner object).

  Omits `"theme"` when all values are nil and `"sendDataModel"` when false.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = msg) do
    base = %{"surfaceId" => msg.surface_id, "catalogId" => msg.catalog_id}

    base =
      case theme_to_map(msg.theme) do
        map when map == %{} -> base
        theme_map -> Map.put(base, "theme", theme_map)
      end

    if msg.send_data_model, do: Map.put(base, "sendDataModel", true), else: base
  end

  defp theme_to_map(theme) do
    pairs = [
      {"primaryColor", theme[:primary_color]},
      {"iconUrl", theme[:icon_url]},
      {"agentDisplayName", theme[:agent_display_name]}
    ]

    for {key, val} <- pairs, val != nil, into: %{}, do: {key, val}
  end
end
