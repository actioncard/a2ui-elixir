defmodule A2UI.Components.Video do
  @moduledoc """
  Renders an A2UI Video component.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    url = resolve_prop(props, "url", assigns.ctx, "")
    autoplay = Map.get(props, "autoplay", false)
    controls = Map.get(props, "controls", true)
    a11y = a11y_attrs(assigns.component.accessibility)

    assigns = assign(assigns, url: url, autoplay: autoplay, controls: controls, a11y: a11y)

    ~H"""
    <div class="a2ui-video">
      <video src={@url} autoplay={@autoplay} controls={@controls} {@a11y} />
    </div>
    """
  end
end
