defmodule A2UI.ComponentTest do
  use ExUnit.Case, async: true

  alias A2UI.Component

  describe "to_map/1" do
    test "round-trips basic component" do
      original = %Component{
        id: "header",
        type: "Text",
        props: %{"text" => "Hello", "variant" => "h1"}
      }

      assert original == original |> Component.to_map() |> Component.from_map()
    end

    test "includes accessibility when present" do
      original = %Component{
        id: "btn",
        type: "Button",
        props: %{"label" => "Submit"},
        accessibility: %{"role" => "button", "label" => "Submit form"}
      }

      map = Component.to_map(original)
      assert map["accessibility"] == %{"role" => "button", "label" => "Submit form"}
      assert original == Component.from_map(map)
    end

    test "omits accessibility when nil" do
      map =
        Component.to_map(%Component{
          id: "x",
          type: "Text",
          props: %{"text" => "hi"}
        })

      refute Map.has_key?(map, "accessibility")
    end
  end
end
