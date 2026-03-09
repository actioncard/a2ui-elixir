defmodule A2UI.Components.AudioPlayer do
  @moduledoc """
  Renders an A2UI AudioPlayer component.
  """

  use A2UI.ComponentRenderer

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  @impl true
  def render(assigns) do
    props = assigns.component.props
    url = resolve_prop(props, "url", assigns.ctx, "")
    controls = Map.get(props, "controls", true)
    a11y = a11y_attrs(assigns.component.accessibility)

    assigns = assign(assigns, url: url, controls: controls, a11y: a11y)

    ~H"""
    <div class="a2ui-audio-player">
      <audio src={@url} controls={@controls} {@a11y} />
    </div>
    """
  end
end
