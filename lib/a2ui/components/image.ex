defmodule A2UI.Components.Image do
  @moduledoc """
  Renders an A2UI Image component.
  """

  use Phoenix.Component

  alias A2UI.Components.Renderer

  attr :component, :any, required: true
  attr :ctx, :any, required: true

  def render(assigns) do
    props = assigns.component.props
    url = Renderer.resolve_prop(props, "url", assigns.ctx, "")
    fit = Map.get(props, "fit", "cover")
    a11y = Renderer.a11y_attrs(assigns.component.accessibility)
    alt = get_in(assigns.component.accessibility, ["label"]) || ""
    style = "object-fit:#{fit}"

    assigns = assign(assigns, url: url, alt: alt, style: style, a11y: a11y)

    ~H"""
    <img class="a2ui-image" src={@url} alt={@alt} style={@style} {@a11y} />
    """
  end
end
