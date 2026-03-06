defmodule A2UI.Components.Text do
  @moduledoc """
  Renders an A2UI Text component.

  Maps `variant` to HTML tags: h1-h5, body (default) → `<p>`, caption → `<span>`.
  """

  use Phoenix.Component

  alias A2UI.Components.Renderer

  @variant_tags %{
    "h1" => "h1",
    "h2" => "h2",
    "h3" => "h3",
    "h4" => "h4",
    "h5" => "h5",
    "body" => "p",
    "caption" => "span"
  }

  attr(:component, :any, required: true)
  attr(:ctx, :any, required: true)

  def render(assigns) do
    props = assigns.component.props
    text = Renderer.resolve_prop(props, "text", assigns.ctx, "")
    variant = Map.get(props, "variant", "body")
    tag = Map.get(@variant_tags, variant, "p")
    a11y = Renderer.a11y_attrs(assigns.component.accessibility)
    class = "a2ui-text a2ui-text--#{variant}"

    assigns = assign(assigns, text: text, tag: tag, a11y: a11y, class: class)

    ~H"""
    <.dynamic_tag tag_name={@tag} class={@class} {@a11y}>{@text}</.dynamic_tag>
    """
  end
end
