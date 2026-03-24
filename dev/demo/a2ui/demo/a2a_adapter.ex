defmodule A2UI.Demo.A2AAdapter do
  @moduledoc false
  use A2UI.A2A,
    agent: A2UI.Demo.Agent,
    name: "a2ui-demo",
    description: "A2UI restaurant booking demo over A2A"
end
