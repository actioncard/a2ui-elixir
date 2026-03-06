defmodule A2UI.ComponentTree do
  @moduledoc """
  Operations on the A2UI component adjacency list.

  Components are stored as a flat `%{id => %Component{}}` map. This module
  provides functions to walk the tree via ID references without reconstructing
  a nested structure.
  """

  alias A2UI.{Component, DataModel}

  @doc """
  Finds the root component (id `"root"`) in the components map.

  ## Examples

      iex> components = %{"root" => %A2UI.Component{id: "root", type: "Column"}}
      iex> A2UI.ComponentTree.root(components)
      {:ok, %A2UI.Component{id: "root", type: "Column"}}
  """
  @spec root(%{String.t() => Component.t()}) :: {:ok, Component.t()} | {:error, :no_root}
  def root(components) do
    case Map.fetch(components, "root") do
      {:ok, component} -> {:ok, component}
      :error -> {:error, :no_root}
    end
  end

  @doc """
  Determines how a component references its children.

  Returns:
  - `{:ids, [id]}` — for `"child"` (single) or `"children"` (list) props
  - `{:template, template_config}` — for `"children"` map with `"template"` key
  - `{:none, []}` — when no children are referenced

  ## Examples

      iex> comp = %A2UI.Component{id: "c", type: "Card", props: %{"child" => "inner"}}
      iex> A2UI.ComponentTree.child_ids(comp)
      {:ids, ["inner"]}

      iex> comp = %A2UI.Component{id: "r", type: "Row", props: %{"children" => ["a", "b"]}}
      iex> A2UI.ComponentTree.child_ids(comp)
      {:ids, ["a", "b"]}
  """
  @spec child_ids(Component.t()) ::
          {:ids, [String.t()]}
          | {:template, map()}
          | {:none, []}
  def child_ids(%Component{props: props}) do
    cond do
      Map.has_key?(props, "child") ->
        {:ids, [props["child"]]}

      is_list(props["children"]) ->
        {:ids, props["children"]}

      is_map(props["children"]) and is_map(props["children"]["template"]) ->
        {:template, props["children"]["template"]}

      true ->
        {:none, []}
    end
  end

  @doc """
  Expands a template configuration into virtual component instances.

  Given a template config like `%{"componentId" => "item", "path" => "/items"}`,
  looks up the array at `path` in the data model and produces one entry per element.

  Returns `{:ok, [{virtual_id, index, scope_path}]}` or `{:error, reason}`.

  Virtual IDs follow the pattern `"componentId__index"`.
  Scope paths follow `"base_path/path/index"`.
  """
  @spec expand_template(map(), DataModel.t(), String.t()) ::
          {:ok, [{String.t(), non_neg_integer(), String.t()}]} | {:error, atom()}
  def expand_template(template_config, data_model, base_path \\ "") do
    %{"componentId" => component_id, "path" => path} = template_config
    full_path = base_path <> path

    case DataModel.get(data_model, full_path) do
      {:ok, items} when is_list(items) ->
        entries =
          items
          |> Enum.with_index()
          |> Enum.map(fn {_item, index} ->
            virtual_id = "#{component_id}__#{index}"
            scope_path = "#{full_path}/#{index}"
            {virtual_id, index, scope_path}
          end)

        {:ok, entries}

      {:ok, _not_a_list} ->
        {:error, :not_an_array}

      :error ->
        {:error, :path_not_found}
    end
  end

  @doc """
  Validates that all child ID references in components point to existing components.

  Returns `:ok` if all references are valid, or `{:error, {:missing_refs, list}}`
  with a list of `{parent_id, missing_child_id}` tuples.
  """
  @spec validate_references(%{String.t() => Component.t()}) ::
          :ok | {:error, {:missing_refs, [{String.t(), String.t()}]}}
  def validate_references(components) do
    missing =
      for {_id, component} <- components,
          {:ids, child_ids} <- [child_ids(component)],
          child_id <- child_ids,
          not Map.has_key?(components, child_id) do
        {component.id, child_id}
      end

    case missing do
      [] -> :ok
      refs -> {:error, {:missing_refs, refs}}
    end
  end
end
