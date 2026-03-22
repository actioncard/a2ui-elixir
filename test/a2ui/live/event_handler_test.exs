defmodule A2UI.Live.EventHandlerTest do
  use ExUnit.Case, async: true

  alias A2UI.Live.EventHandler
  alias A2UI.{DataModel, SurfaceManager}
  alias A2UI.Protocol.Messages.CreateSurface

  defp make_surfaces(opts \\ []) do
    data = Keyword.get(opts, :data, %{})
    send_data_model = Keyword.get(opts, :send_data_model, false)

    {:ok, surfaces} =
      SurfaceManager.apply_message(SurfaceManager.new(), %CreateSurface{
        surface_id: "s1",
        catalog_id: "basic",
        send_data_model: send_data_model
      })

    if data == %{} do
      surfaces
    else
      Enum.reduce(data, surfaces, fn {path, value}, acc ->
        {:ok, acc} =
          SurfaceManager.apply_message(acc, %A2UI.Protocol.Messages.UpdateDataModel{
            surface_id: "s1",
            path: path,
            value: value,
            has_value: true
          })

        acc
      end)
    end
  end

  defp action_params(action_map, opts \\ []) do
    %{
      "surface-id" => Keyword.get(opts, :surface_id, "s1"),
      "component-id" => Keyword.get(opts, :component_id, "btn1"),
      "action" => Jason.encode!(action_map)
    }
  end

  # ── build_action ──

  describe "build_action/2" do
    test "happy path builds action struct" do
      surfaces = make_surfaces()
      params = action_params(%{"name" => "submit", "context" => %{"key" => "val"}})

      assert {:ok, action, metadata} = EventHandler.build_action(params, surfaces)
      assert action.name == "submit"
      assert action.surface_id == "s1"
      assert action.source_component_id == "btn1"
      assert action.context == %{"key" => "val"}
      assert action.timestamp != nil
      assert metadata.surface.id == "s1"
      assert metadata.send_data_model == false
      assert metadata.data_model == nil
    end

    test "includes data_model when send_data_model is true" do
      surfaces = make_surfaces(send_data_model: true, data: %{"/name" => "Alice"})
      params = action_params(%{"name" => "submit"})

      assert {:ok, _action, metadata} = EventHandler.build_action(params, surfaces)
      assert metadata.send_data_model == true
      assert metadata.data_model == %{"name" => "Alice"}
    end

    test "resolves context bindings from data model" do
      surfaces = make_surfaces(data: %{"/user/name" => "Alice"})

      params =
        action_params(%{
          "name" => "greet",
          "context" => %{"userName" => %{"path" => "/user/name"}}
        })

      assert {:ok, action, _} = EventHandler.build_action(params, surfaces)
      assert action.context == %{"userName" => "Alice"}
    end

    test "keeps raw value when binding cannot resolve" do
      surfaces = make_surfaces()

      params =
        action_params(%{
          "name" => "greet",
          "context" => %{"userName" => %{"path" => "/nonexistent"}}
        })

      assert {:ok, action, _} = EventHandler.build_action(params, surfaces)
      assert action.context == %{"userName" => %{"path" => "/nonexistent"}}
    end

    test "returns error on missing surface-id" do
      params = %{"component-id" => "btn1", "action" => "{}"}
      assert {:error, :missing_param} = EventHandler.build_action(params, %{})
    end

    test "returns error on missing component-id" do
      params = %{"surface-id" => "s1", "action" => "{}"}
      assert {:error, :missing_param} = EventHandler.build_action(params, %{})
    end

    test "returns error on missing action" do
      params = %{"surface-id" => "s1", "component-id" => "btn1"}
      assert {:error, :missing_param} = EventHandler.build_action(params, %{})
    end

    test "returns error on invalid JSON" do
      params = %{"surface-id" => "s1", "component-id" => "btn1", "action" => "not json"}
      surfaces = make_surfaces()
      assert {:error, :invalid_json} = EventHandler.build_action(params, surfaces)
    end

    test "returns error when surface not found" do
      params = action_params(%{"name" => "submit"}, surface_id: "unknown")
      assert {:error, :surface_not_found} = EventHandler.build_action(params, make_surfaces())
    end

    test "handles nil context gracefully" do
      surfaces = make_surfaces()
      params = action_params(%{"name" => "submit"})

      assert {:ok, action, _} = EventHandler.build_action(params, surfaces)
      assert action.context == %{}
    end
  end

  # ── apply_input_change ──

  describe "apply_input_change/2 - text field" do
    test "sets string value" do
      surfaces = make_surfaces(data: %{"/name" => ""})

      params = %{
        "surface-id" => "s1",
        "path" => "/name",
        "_target" => ["field1"],
        "field1" => "Alice"
      }

      assert {:ok, updated} = EventHandler.apply_input_change(params, surfaces)
      assert {:ok, "Alice"} = DataModel.get(updated["s1"].data_model, "/name")
    end
  end

  describe "apply_input_change/2 - slider (integer coercion)" do
    test "coerces string to integer" do
      surfaces = make_surfaces(data: %{"/volume" => 50})

      params = %{
        "surface-id" => "s1",
        "path" => "/volume",
        "_target" => ["slider1"],
        "slider1" => "75"
      }

      assert {:ok, updated} = EventHandler.apply_input_change(params, surfaces)
      assert {:ok, 75} = DataModel.get(updated["s1"].data_model, "/volume")
    end

    test "falls back to current value on invalid integer" do
      surfaces = make_surfaces(data: %{"/volume" => 50})

      params = %{
        "surface-id" => "s1",
        "path" => "/volume",
        "_target" => ["slider1"],
        "slider1" => "abc"
      }

      assert {:ok, updated} = EventHandler.apply_input_change(params, surfaces)
      assert {:ok, 50} = DataModel.get(updated["s1"].data_model, "/volume")
    end
  end

  describe "apply_input_change/2 - checkbox (boolean coercion)" do
    test "coerces 'true' to true" do
      surfaces = make_surfaces(data: %{"/agreed" => false})

      params = %{
        "surface-id" => "s1",
        "path" => "/agreed",
        "_target" => ["cb1"],
        "cb1" => "true"
      }

      assert {:ok, updated} = EventHandler.apply_input_change(params, surfaces)
      assert {:ok, true} = DataModel.get(updated["s1"].data_model, "/agreed")
    end

    test "coerces 'false' to false" do
      surfaces = make_surfaces(data: %{"/agreed" => true})

      params = %{
        "surface-id" => "s1",
        "path" => "/agreed",
        "_target" => ["cb1"],
        "cb1" => "false"
      }

      assert {:ok, updated} = EventHandler.apply_input_change(params, surfaces)
      assert {:ok, false} = DataModel.get(updated["s1"].data_model, "/agreed")
    end
  end

  describe "apply_input_change/2 - float coercion" do
    test "coerces string to float" do
      surfaces = make_surfaces(data: %{"/rating" => 3.5})

      params = %{
        "surface-id" => "s1",
        "path" => "/rating",
        "_target" => ["rate1"],
        "rate1" => "4.2"
      }

      assert {:ok, updated} = EventHandler.apply_input_change(params, surfaces)
      assert {:ok, 4.2} = DataModel.get(updated["s1"].data_model, "/rating")
    end
  end

  describe "apply_input_change/2 - radio (list replace)" do
    test "replaces list with single selection" do
      surfaces = make_surfaces(data: %{"/color" => ["red"]})

      params = %{
        "surface-id" => "s1",
        "path" => "/color",
        "input-type" => "radio",
        "_target" => ["picker1"],
        "picker1" => "blue"
      }

      assert {:ok, updated} = EventHandler.apply_input_change(params, surfaces)
      assert {:ok, ["blue"]} = DataModel.get(updated["s1"].data_model, "/color")
    end
  end

  describe "apply_input_change/2 - multi-select (list toggle)" do
    test "adds value not in list" do
      surfaces = make_surfaces(data: %{"/tags" => ["a", "b"]})

      params = %{
        "surface-id" => "s1",
        "path" => "/tags",
        "input-type" => "checkbox",
        "_target" => ["picker1"],
        "picker1" => "c"
      }

      assert {:ok, updated} = EventHandler.apply_input_change(params, surfaces)
      assert {:ok, ["a", "b", "c"]} = DataModel.get(updated["s1"].data_model, "/tags")
    end

    test "removes value already in list" do
      surfaces = make_surfaces(data: %{"/tags" => ["a", "b", "c"]})

      params = %{
        "surface-id" => "s1",
        "path" => "/tags",
        "input-type" => "checkbox",
        "_target" => ["picker1"],
        "picker1" => "b"
      }

      assert {:ok, updated} = EventHandler.apply_input_change(params, surfaces)
      assert {:ok, ["a", "c"]} = DataModel.get(updated["s1"].data_model, "/tags")
    end
  end

  # ── build_error ──

  describe "build_error/1" do
    test "happy path builds error struct" do
      params = %{
        "code" => "VALIDATION_FAILED",
        "surface-id" => "s1",
        "path" => "/name",
        "message" => "Required"
      }

      assert {:ok, error, metadata} = EventHandler.build_error(params)
      assert error.code == "VALIDATION_FAILED"
      assert error.surface_id == "s1"
      assert error.path == "/name"
      assert error.message == "Required"
      assert is_map(metadata)
    end

    test "returns error on missing code" do
      params = %{"surface-id" => "s1", "path" => "/name", "message" => "Required"}
      assert {:error, :missing_param} = EventHandler.build_error(params)
    end

    test "returns error on missing surface-id" do
      params = %{"code" => "VALIDATION_FAILED", "path" => "/name", "message" => "Required"}
      assert {:error, :missing_param} = EventHandler.build_error(params)
    end

    test "returns error on missing path" do
      params = %{"code" => "VALIDATION_FAILED", "surface-id" => "s1", "message" => "Required"}
      assert {:error, :missing_param} = EventHandler.build_error(params)
    end

    test "returns error on missing message" do
      params = %{"code" => "VALIDATION_FAILED", "surface-id" => "s1", "path" => "/name"}
      assert {:error, :missing_param} = EventHandler.build_error(params)
    end
  end

  describe "apply_input_change/2 - error cases" do
    test "returns error on missing surface" do
      params = %{"surface-id" => "unknown", "path" => "/x", "_target" => ["f"], "f" => "v"}
      assert {:error, :surface_not_found} = EventHandler.apply_input_change(params, %{})
    end

    test "returns error on missing path" do
      surfaces = make_surfaces()
      params = %{"surface-id" => "s1", "_target" => ["f"], "f" => "v"}
      assert {:error, :missing_param} = EventHandler.apply_input_change(params, surfaces)
    end
  end

  describe "apply_input_change/2 - fallback extraction" do
    test "extracts value when _target is missing" do
      surfaces = make_surfaces(data: %{"/name" => ""})

      params = %{
        "surface-id" => "s1",
        "path" => "/name",
        "field1" => "Bob"
      }

      assert {:ok, updated} = EventHandler.apply_input_change(params, surfaces)
      assert {:ok, "Bob"} = DataModel.get(updated["s1"].data_model, "/name")
    end
  end
end
