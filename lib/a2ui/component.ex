defmodule A2UI.Component do
  @moduledoc """
  Represents an A2UI component in the adjacency list.

  Components are flat — parent-child relationships use ID references
  via `child`/`children` props.
  """

  defstruct [:id, :type, props: %{}, accessibility: nil]

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          props: map(),
          accessibility: map() | nil
        }

  @reserved_keys ~w(id component accessibility)

  @doc """
  Parses a raw JSON map into a Component struct.

  Extracts `id`, `component` (as type), and `accessibility`.
  All remaining keys become props.

  ## Examples

      iex> A2UI.Component.from_map(%{"id" => "header", "component" => "Text", "text" => "Hello", "variant" => "h1"})
      %A2UI.Component{id: "header", type: "Text", props: %{"text" => "Hello", "variant" => "h1"}}
  """
  @spec from_map(map()) :: t()
  def from_map(%{"id" => id, "component" => type} = map) do
    accessibility = Map.get(map, "accessibility")
    props = Map.drop(map, @reserved_keys)

    %__MODULE__{
      id: id,
      type: type,
      props: props,
      accessibility: accessibility
    }
  end

  @doc """
  Converts a Component struct back to a JSON-compatible map.

  Inverse of `from_map/1`. Props are spread as top-level keys,
  and `"accessibility"` is included only when non-nil.

  ## Examples

      iex> A2UI.Component.to_map(%A2UI.Component{id: "h", type: "Text", props: %{"text" => "Hi"}})
      %{"id" => "h", "component" => "Text", "text" => "Hi"}
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = component) do
    base = Map.merge(component.props, %{"id" => component.id, "component" => component.type})

    if component.accessibility do
      Map.put(base, "accessibility", component.accessibility)
    else
      base
    end
  end
end
