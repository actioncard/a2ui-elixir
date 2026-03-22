defmodule A2UI.Catalog do
  @moduledoc """
  Compile-time catalog registry for A2UI component type validation.

  The basic catalog is loaded from the official JSON Schema shipped in
  `priv/catalogs/basic_catalog.json`. Valid component types are extracted
  from the `"components"` keys at compile time.

  ## Configuration

  Custom catalogs can be registered at compile time. Values may be either
  a path to a catalog JSON file (relative to the project root) whose
  `"components"` keys are extracted, or an explicit list of type strings:

      config :a2ui, catalogs: %{
        "https://example.com/catalog.json" => "priv/catalogs/my_catalog.json",
        "https://example.com/simple.json" => ["Text", "Button", "MyWidget"]
      }

  The basic catalog (`"https://a2ui.org/specification/v0_9/basic_catalog.json"`)
  is always registered. Unknown catalog IDs are handled permissively — validation
  is skipped when the renderer does not recognize the catalog. A `nil` catalog ID
  also skips validation.
  """

  @basic_catalog_id "https://a2ui.org/specification/v0_9/basic_catalog.json"

  @basic_catalog_path Path.join(:code.priv_dir(:a2ui), "catalogs/basic_catalog.json")
  @external_resource @basic_catalog_path

  @basic_types @basic_catalog_path
               |> File.read!()
               |> Jason.decode!()
               |> Map.get("components", %{})
               |> Map.keys()
               |> Map.new(fn type -> {type, true} end)

  @custom_catalogs Application.compile_env(:a2ui, :catalogs, %{})
                   |> Enum.map(fn
                     {id, path} when is_binary(path) ->
                       types =
                         path
                         |> File.read!()
                         |> Jason.decode!()
                         |> Map.get("components", %{})
                         |> Map.keys()
                         |> Map.new(fn type -> {type, true} end)

                       {id, types}

                     {id, types} when is_list(types) ->
                       {id, Map.new(types, fn type -> {type, true} end)}
                   end)
                   |> Map.new()

  @all_catalogs Map.put(@custom_catalogs, @basic_catalog_id, @basic_types)

  @doc """
  Returns the basic catalog ID URL string.
  """
  @spec basic_catalog_id() :: String.t()
  def basic_catalog_id, do: @basic_catalog_id

  @doc """
  Validates that all component types are allowed by the given catalog.

  Returns `:ok` when:
  - `catalog_id` is `nil` (validation skipped)
  - `catalog_id` is not recognized (permissive — unknown catalogs are accepted)
  - All component types are present in the catalog

  Returns `{:error, {:invalid_component_types, types}}` only when the
  catalog is known and contains types not in its allowed set.
  """
  @spec validate_types([A2UI.Component.t()], String.t() | nil) ::
          :ok | {:error, {:invalid_component_types, [String.t()]}}
  def validate_types(_components, nil), do: :ok

  def validate_types(components, catalog_id) do
    case Map.fetch(@all_catalogs, catalog_id) do
      {:ok, type_map} ->
        invalid =
          components
          |> Enum.map(& &1.type)
          |> Enum.reject(&Map.has_key?(type_map, &1))
          |> Enum.uniq()

        case invalid do
          [] -> :ok
          types -> {:error, {:invalid_component_types, types}}
        end

      :error ->
        :ok
    end
  end
end
