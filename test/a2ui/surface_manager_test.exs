defmodule A2UI.SurfaceManagerTest do
  use ExUnit.Case, async: true

  alias A2UI.{Component, DataModel, Surface, SurfaceManager}

  alias A2UI.Protocol.Messages.{
    CreateSurface,
    DeleteSurface,
    UpdateComponents,
    UpdateDataModel
  }

  defp create_surface_msg(surface_id \\ "main") do
    %CreateSurface{
      surface_id: surface_id,
      catalog_id: "https://a2ui.org/specification/v0_9/basic_catalog.json",
      theme: %{primary_color: "#1a73e8"},
      send_data_model: false
    }
  end

  defp setup_surface(surface_id \\ "main") do
    surfaces = SurfaceManager.new()
    {:ok, surfaces} = SurfaceManager.apply_message(surfaces, create_surface_msg(surface_id))
    surfaces
  end

  describe "new/0" do
    test "returns empty map" do
      assert %{} = SurfaceManager.new()
    end
  end

  describe "CreateSurface" do
    test "creates a new surface" do
      surfaces = SurfaceManager.new()
      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, create_surface_msg())

      assert Map.has_key?(surfaces, "main")
      surface = surfaces["main"]
      assert %Surface{} = surface
      assert surface.id == "main"
      assert surface.catalog_id == "https://a2ui.org/specification/v0_9/basic_catalog.json"
      assert surface.theme == %{primary_color: "#1a73e8"}
      assert surface.components == %{}
      assert surface.data_model == DataModel.new()
    end

    test "is idempotent — replaces existing surface" do
      surfaces = setup_surface()

      # Apply create again with different catalog
      msg = %CreateSurface{
        surface_id: "main",
        catalog_id: "other-catalog",
        theme: %{},
        send_data_model: true
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, msg)
      assert surfaces["main"].catalog_id == "other-catalog"
      assert surfaces["main"].send_data_model == true
      # Components should be reset
      assert surfaces["main"].components == %{}
    end

    test "multiple surfaces" do
      surfaces = SurfaceManager.new()
      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, create_surface_msg("s1"))
      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, create_surface_msg("s2"))

      assert Map.has_key?(surfaces, "s1")
      assert Map.has_key?(surfaces, "s2")
    end
  end

  describe "UpdateComponents" do
    test "adds components to surface" do
      surfaces = setup_surface()

      msg = %UpdateComponents{
        surface_id: "main",
        components: [
          %Component{id: "root", type: "Column", props: %{"children" => ["header"]}},
          %Component{id: "header", type: "Text", props: %{"text" => "Hello"}}
        ]
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, msg)

      assert map_size(surfaces["main"].components) == 2
      assert surfaces["main"].components["root"].type == "Column"
      assert surfaces["main"].components["header"].type == "Text"
    end

    test "merges with existing components" do
      surfaces = setup_surface()

      msg1 = %UpdateComponents{
        surface_id: "main",
        components: [
          %Component{id: "root", type: "Column", props: %{"children" => ["a"]}},
          %Component{id: "a", type: "Text", props: %{"text" => "first"}}
        ]
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, msg1)

      msg2 = %UpdateComponents{
        surface_id: "main",
        components: [
          %Component{id: "b", type: "Text", props: %{"text" => "second"}}
        ]
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, msg2)

      assert map_size(surfaces["main"].components) == 3
      assert surfaces["main"].components["a"].props["text"] == "first"
      assert surfaces["main"].components["b"].props["text"] == "second"
    end

    test "replaces existing component by ID" do
      surfaces = setup_surface()

      msg1 = %UpdateComponents{
        surface_id: "main",
        components: [%Component{id: "header", type: "Text", props: %{"text" => "old"}}]
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, msg1)

      msg2 = %UpdateComponents{
        surface_id: "main",
        components: [%Component{id: "header", type: "Text", props: %{"text" => "new"}}]
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, msg2)

      assert surfaces["main"].components["header"].props["text"] == "new"
    end

    test "errors when surface not found" do
      surfaces = SurfaceManager.new()

      msg = %UpdateComponents{
        surface_id: "missing",
        components: [%Component{id: "x", type: "Text", props: %{}}]
      }

      assert {:error, :surface_not_found} = SurfaceManager.apply_message(surfaces, msg)
    end
  end

  describe "UpdateDataModel" do
    test "sets a value" do
      surfaces = setup_surface()

      msg = %UpdateDataModel{
        surface_id: "main",
        path: "/user/name",
        value: "Alice",
        has_value: true
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, msg)
      assert {:ok, "Alice"} = DataModel.get(surfaces["main"].data_model, "/user/name")
    end

    test "sets at root" do
      surfaces = setup_surface()

      msg = %UpdateDataModel{
        surface_id: "main",
        path: "/",
        value: %{"greeting" => "hello"},
        has_value: true
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, msg)
      assert {:ok, %{"greeting" => "hello"}} = DataModel.get(surfaces["main"].data_model, "/")
    end

    test "deletes when has_value is false" do
      surfaces = setup_surface()

      # First set a value
      set_msg = %UpdateDataModel{
        surface_id: "main",
        path: "/user/name",
        value: "Alice",
        has_value: true
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, set_msg)

      # Then delete it
      del_msg = %UpdateDataModel{
        surface_id: "main",
        path: "/user/name",
        has_value: false
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, del_msg)
      assert :error = DataModel.get(surfaces["main"].data_model, "/user/name")
    end

    test "sets explicit null (nil) value" do
      surfaces = setup_surface()

      msg = %UpdateDataModel{
        surface_id: "main",
        path: "/field",
        value: nil,
        has_value: true
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, msg)
      assert {:ok, nil} = DataModel.get(surfaces["main"].data_model, "/field")
    end

    test "errors when surface not found" do
      surfaces = SurfaceManager.new()

      msg = %UpdateDataModel{
        surface_id: "missing",
        path: "/x",
        value: 1,
        has_value: true
      }

      assert {:error, :surface_not_found} = SurfaceManager.apply_message(surfaces, msg)
    end
  end

  describe "DeleteSurface" do
    test "removes a surface" do
      surfaces = setup_surface()
      msg = %DeleteSurface{surface_id: "main"}

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, msg)
      refute Map.has_key?(surfaces, "main")
    end

    test "errors when surface not found" do
      surfaces = SurfaceManager.new()
      msg = %DeleteSurface{surface_id: "missing"}

      assert {:error, :surface_not_found} = SurfaceManager.apply_message(surfaces, msg)
    end
  end

  describe "full message sequence" do
    test "restaurant booking scenario" do
      surfaces = SurfaceManager.new()

      # 1. Create surface
      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, create_surface_msg())

      # 2. Add components
      components_msg = %UpdateComponents{
        surface_id: "main",
        components: [
          %Component{id: "root", type: "Column", props: %{"children" => ["header", "form"]}},
          %Component{id: "header", type: "Text", props: %{"text" => "# Book Your Table"}},
          %Component{id: "form", type: "Column", props: %{"children" => ["date-input", "submit"]}},
          %Component{
            id: "date-input",
            type: "DateTimeInput",
            props: %{"label" => "Date", "value" => %{"path" => "/reservation/date"}}
          },
          %Component{id: "submit", type: "Button", props: %{"child" => "submit-text"}},
          %Component{id: "submit-text", type: "Text", props: %{"text" => "Confirm"}}
        ]
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, components_msg)
      assert map_size(surfaces["main"].components) == 6

      # 3. Set data model
      data_msg = %UpdateDataModel{
        surface_id: "main",
        path: "/reservation",
        value: %{"date" => "2025-12-15", "guests" => 2},
        has_value: true
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, data_msg)
      assert {:ok, "2025-12-15"} = DataModel.get(surfaces["main"].data_model, "/reservation/date")

      # 4. Update a component (streaming update)
      update_msg = %UpdateComponents{
        surface_id: "main",
        components: [
          %Component{id: "header", type: "Text", props: %{"text" => "# Updated Title"}}
        ]
      }

      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, update_msg)
      assert surfaces["main"].components["header"].props["text"] == "# Updated Title"
      # Other components still present
      assert map_size(surfaces["main"].components) == 6

      # 5. Delete surface
      {:ok, surfaces} = SurfaceManager.apply_message(surfaces, %DeleteSurface{surface_id: "main"})
      assert surfaces == %{}
    end
  end
end
