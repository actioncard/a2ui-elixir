defmodule A2UI.Components.RenderContext do
  @moduledoc """
  Threads rendering state through the component tree.

  Holds the component map, data model, surface ID, and optional scope path
  (for template-expanded children with relative bindings).
  """

  alias A2UI.{Surface, DataModel}

  defstruct [:components, :data_model, :surface_id, scope_path: nil]

  @type t :: %__MODULE__{
          components: %{String.t() => A2UI.Component.t()},
          data_model: DataModel.t(),
          surface_id: String.t(),
          scope_path: String.t() | nil
        }

  @doc """
  Builds a RenderContext from a Surface struct.
  """
  @spec from_surface(Surface.t()) :: t()
  def from_surface(%Surface{} = surface) do
    %__MODULE__{
      components: surface.components,
      data_model: surface.data_model,
      surface_id: surface.id
    }
  end

  @doc """
  Returns a new context with the given scope path set.
  """
  @spec with_scope(t(), String.t() | nil) :: t()
  def with_scope(%__MODULE__{} = ctx, scope_path) do
    %{ctx | scope_path: scope_path}
  end
end
