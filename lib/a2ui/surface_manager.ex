defmodule A2UI.SurfaceManager do
  @moduledoc """
  Pure functional state manager for A2UI surfaces.

  Manages a `%{surface_id => %Surface{}}` map by applying protocol messages.
  No GenServer — surfaces live in LiveView assigns.
  """

  alias A2UI.{DataModel, Surface}

  alias A2UI.Protocol.Messages.{
    CreateSurface,
    DeleteSurface,
    UpdateComponents,
    UpdateDataModel
  }

  @type surfaces :: %{String.t() => Surface.t()}

  @doc """
  Creates an empty surfaces map.
  """
  @spec new() :: surfaces()
  def new, do: %{}

  @doc """
  Applies a protocol message to the surfaces map.

  Returns `{:ok, updated_surfaces}` or `{:error, reason}`.
  """
  @spec apply_message(surfaces(), struct()) :: {:ok, surfaces()} | {:error, atom()}
  def apply_message(surfaces, %CreateSurface{} = msg) do
    surface = %Surface{
      id: msg.surface_id,
      catalog_id: msg.catalog_id,
      theme: msg.theme,
      send_data_model: msg.send_data_model,
      components: %{},
      data_model: DataModel.new()
    }

    {:ok, Map.put(surfaces, msg.surface_id, surface)}
  end

  def apply_message(surfaces, %UpdateComponents{} = msg) do
    with {:ok, surface} <- fetch_surface(surfaces, msg.surface_id) do
      updated_components =
        Enum.reduce(msg.components, surface.components, fn component, acc ->
          Map.put(acc, component.id, component)
        end)

      {:ok, Map.put(surfaces, msg.surface_id, %{surface | components: updated_components})}
    end
  end

  def apply_message(surfaces, %UpdateDataModel{} = msg) do
    with {:ok, surface} <- fetch_surface(surfaces, msg.surface_id) do
      result =
        if msg.has_value do
          DataModel.set(surface.data_model, msg.path, msg.value)
        else
          DataModel.delete(surface.data_model, msg.path)
        end

      case result do
        {:ok, data_model} ->
          {:ok, Map.put(surfaces, msg.surface_id, %{surface | data_model: data_model})}

        {:error, _} = error ->
          error
      end
    end
  end

  def apply_message(surfaces, %DeleteSurface{} = msg) do
    if Map.has_key?(surfaces, msg.surface_id) do
      {:ok, Map.delete(surfaces, msg.surface_id)}
    else
      {:error, :surface_not_found}
    end
  end

  defp fetch_surface(surfaces, surface_id) do
    case Map.fetch(surfaces, surface_id) do
      {:ok, surface} -> {:ok, surface}
      :error -> {:error, :surface_not_found}
    end
  end
end
