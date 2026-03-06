defmodule A2UI.Live.EventHandler do
  @moduledoc """
  Pure functions for handling Phoenix LiveView events in A2UI.

  Converts `phx-click` and `phx-change` event params into protocol-level
  actions and data model updates. No socket state — fully unit-testable.
  """

  alias A2UI.DataModel
  alias A2UI.DataModel.Binding
  alias A2UI.Protocol.Messages.{Action, UpdateDataModel}
  alias A2UI.SurfaceManager

  @doc """
  Builds an Action struct from `a2ui_action` event params.

  Returns `{:ok, action, metadata}` or `{:error, reason}`.

  The metadata map includes:
  - `:surface` — the surface struct
  - `:send_data_model` — whether the surface wants data model echoed back
  - `:data_model` — the data model data (if `send_data_model` is true)
  """
  @spec build_action(map(), SurfaceManager.surfaces()) ::
          {:ok, Action.t(), map()} | {:error, atom()}
  def build_action(params, surfaces) do
    with {:ok, surface_id} <- fetch_param(params, "surface-id"),
         {:ok, component_id} <- fetch_param(params, "component-id"),
         {:ok, action_json} <- fetch_param(params, "action"),
         {:ok, action_data} <- decode_json(action_json),
         {:ok, surface} <- fetch_surface(surfaces, surface_id) do
      context = resolve_context(action_data["context"], surface)

      action = %Action{
        name: action_data["name"],
        surface_id: surface_id,
        source_component_id: component_id,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        context: context
      }

      send_dm = surface.send_data_model

      metadata = %{
        surface: surface,
        send_data_model: send_dm,
        data_model: if(send_dm, do: surface.data_model.data)
      }

      {:ok, action, metadata}
    end
  end

  @doc """
  Applies an `a2ui_input_change` event to the surfaces map.

  Extracts the input value from params, coerces it to match the existing
  data model type at the target path, and applies the update.

  Returns `{:ok, updated_surfaces}` or `{:error, reason}`.
  """
  @spec apply_input_change(map(), SurfaceManager.surfaces()) ::
          {:ok, SurfaceManager.surfaces()} | {:error, atom()}
  def apply_input_change(params, surfaces) do
    with {:ok, surface_id} <- fetch_param(params, "surface-id"),
         {:ok, path} <- fetch_param(params, "path"),
         {:ok, surface} <- fetch_surface(surfaces, surface_id) do
      raw_value = extract_input_value(params)
      current_value = get_current_value(surface.data_model, path)
      coerced = coerce_value(raw_value, current_value, params)

      msg = %UpdateDataModel{
        surface_id: surface_id,
        path: path,
        value: coerced,
        has_value: true
      }

      SurfaceManager.apply_message(surfaces, msg)
    end
  end

  # ── Private helpers ──

  defp fetch_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, :missing_param}
    end
  end

  defp decode_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:error, :invalid_json}
    end
  end

  defp decode_json(_), do: {:error, :invalid_json}

  defp fetch_surface(surfaces, surface_id) do
    case Map.fetch(surfaces, surface_id) do
      {:ok, surface} -> {:ok, surface}
      :error -> {:error, :surface_not_found}
    end
  end

  defp resolve_context(nil, _surface), do: %{}

  defp resolve_context(context, surface) when is_map(context) do
    Map.new(context, fn {key, value} ->
      case Binding.resolve(value, surface.data_model) do
        {:ok, resolved} -> {key, resolved}
        :error -> {key, value}
      end
    end)
  end

  defp resolve_context(_context, _surface), do: %{}

  defp extract_input_value(params) do
    case Map.get(params, "_target") do
      [field | _] -> Map.get(params, field)
      _ -> extract_fallback_value(params)
    end
  end

  defp extract_fallback_value(params) do
    # Try common value keys, excluding metadata params
    reserved = ~w(surface-id path input-type _target _csrf_token)

    params
    |> Map.drop(reserved)
    |> Map.values()
    |> List.first()
  end

  defp get_current_value(data_model, path) do
    case DataModel.get(data_model, path) do
      {:ok, value} -> value
      :error -> nil
    end
  end

  defp coerce_value(raw, current, _params) when is_boolean(current) do
    raw in ["true", "on", true]
  end

  defp coerce_value(raw, current, _params) when is_integer(current) do
    case Integer.parse(to_string(raw)) do
      {int, _} -> int
      :error -> current
    end
  end

  defp coerce_value(raw, current, _params) when is_float(current) do
    case Float.parse(to_string(raw)) do
      {float, _} -> float
      :error -> current
    end
  end

  defp coerce_value(raw, current, params) when is_list(current) do
    input_type = Map.get(params, "input-type")

    case input_type do
      "radio" ->
        if raw, do: [raw], else: []

      _ ->
        # checkbox toggle: add or remove from list
        if raw in current do
          List.delete(current, raw)
        else
          current ++ [raw]
        end
    end
  end

  defp coerce_value(raw, _current, _params), do: raw
end
