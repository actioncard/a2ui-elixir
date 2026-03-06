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
end
