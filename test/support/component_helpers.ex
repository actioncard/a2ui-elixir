defmodule A2UI.Test.ComponentHelpers do
  @moduledoc """
  Shared test builders for Phoenix component tests.
  """

  alias A2UI.{Component, Surface, DataModel}
  alias A2UI.Components.RenderContext

  @doc """
  Builds a Component struct with sensible defaults.

      make_component("title", "Text", %{"text" => "Hello", "variant" => "h1"})
  """
  def make_component(id, type, props \\ %{}, opts \\ []) do
    %Component{
      id: id,
      type: type,
      props: props,
      accessibility: Keyword.get(opts, :accessibility)
    }
  end

  @doc """
  Builds a RenderContext from a components map and optional data model.

      components = %{"root" => make_component("root", "Text", %{"text" => "Hi"})}
      ctx = make_ctx(components, "surface-1")
  """
  def make_ctx(components, surface_id \\ "test-surface", opts \\ []) do
    data = Keyword.get(opts, :data, %{})
    scope_path = Keyword.get(opts, :scope_path)

    %RenderContext{
      components: components,
      data_model: DataModel.new(data),
      surface_id: surface_id,
      scope_path: scope_path
    }
  end

  @doc """
  Builds a full Surface struct.
  """
  def make_surface(id, components, opts \\ []) do
    data = Keyword.get(opts, :data, %{})
    theme = Keyword.get(opts, :theme, %{})

    %Surface{
      id: id,
      catalog_id: Keyword.get(opts, :catalog_id),
      components: components,
      data_model: DataModel.new(data),
      theme: theme
    }
  end
end
