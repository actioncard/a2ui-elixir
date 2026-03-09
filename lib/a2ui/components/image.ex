defmodule A2UI.Components.Image do
  @moduledoc """
  Renders an A2UI Image component.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    url = resolve_prop(props, "url", assigns.ctx, "")
    fit = Map.get(props, "fit", "cover")
    a11y = a11y_attrs(assigns.component.accessibility)
    alt = get_in(assigns.component.accessibility, ["label"]) || ""
    classes = ["a2ui-image", "a2ui-image--fit-#{fit}"]

    assigns = assign(assigns, url: url, alt: alt, classes: classes, a11y: a11y)

    ~H"""
    <img class={@classes} src={@url} alt={@alt} {@a11y} />
    """
  end
end
