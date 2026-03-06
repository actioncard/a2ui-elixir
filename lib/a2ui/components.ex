defmodule A2UI.Components do
  @moduledoc """
  Convenience module for A2UI Phoenix function components.

      use A2UI.Components

  Imports the `Renderer` module's public function components (`surface/1`, `component/1`)
  into the calling module.
  """

  defmacro __using__(_opts) do
    quote do
      import A2UI.Components.Renderer, only: [surface: 1, component: 1]
    end
  end
end
