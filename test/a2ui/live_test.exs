defmodule A2UI.LiveTest do
  use ExUnit.Case, async: true

  alias A2UI.Protocol.Messages.{CreateSurface, UpdateComponents, UpdateDataModel}
  alias A2UI.Component

  defp make_socket(surfaces \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        a2ui_surfaces: surfaces
      }
    }
  end

  defp create_surface_with_data(surfaces \\ %{}) do
    {:ok, surfaces} =
      A2UI.SurfaceManager.apply_message(surfaces, %CreateSurface{
        surface_id: "s1",
        catalog_id: "basic"
      })

    surfaces
  end

  # ── __handle_message__ ──

  describe "__handle_message__/2" do
    test "CreateSurface adds surface to assigns" do
      socket = make_socket()
      msg = %CreateSurface{surface_id: "s1", catalog_id: "basic"}

      assert {:noreply, updated_socket} = A2UI.Live.__handle_message__(msg, socket)
      assert Map.has_key?(updated_socket.assigns.a2ui_surfaces, "s1")
    end

    test "UpdateComponents updates existing surface" do
      surfaces = create_surface_with_data()
      socket = make_socket(surfaces)

      component = %Component{id: "root", type: "Text", props: %{"text" => "Hello"}}
      msg = %UpdateComponents{surface_id: "s1", components: [component]}

      assert {:noreply, updated_socket} = A2UI.Live.__handle_message__(msg, socket)
      assert Map.has_key?(updated_socket.assigns.a2ui_surfaces["s1"].components, "root")
    end

    test "error leaves socket unchanged" do
      socket = make_socket()
      # UpdateComponents on non-existent surface
      msg = %UpdateComponents{surface_id: "unknown", components: []}

      assert {:noreply, ^socket} = A2UI.Live.__handle_message__(msg, socket)
    end
  end

  # ── __handle_action__ ──

  describe "__handle_action__/3" do
    test "builds action and calls callback" do
      surfaces = create_surface_with_data()
      socket = make_socket(surfaces)

      params = %{
        "surface-id" => "s1",
        "component-id" => "btn1",
        "action" => Jason.encode!(%{"name" => "submit"})
      }

      callback = fn action, _metadata, socket ->
        assert action.name == "submit"
        {:noreply, socket}
      end

      assert {:noreply, _socket} = A2UI.Live.__handle_action__(params, socket, callback)
    end

    test "bad params returns noreply without calling callback" do
      socket = make_socket()
      params = %{"surface-id" => "missing"}

      callback = fn _action, _metadata, _socket ->
        flunk("callback should not be called")
      end

      assert {:noreply, ^socket} = A2UI.Live.__handle_action__(params, socket, callback)
    end
  end

  # ── __handle_input_change__ ──

  describe "__handle_input_change__/2" do
    test "updates data model in assigns" do
      surfaces = create_surface_with_data()

      {:ok, surfaces} =
        A2UI.SurfaceManager.apply_message(surfaces, %UpdateDataModel{
          surface_id: "s1",
          path: "/name",
          value: "",
          has_value: true
        })

      socket = make_socket(surfaces)

      params = %{
        "surface-id" => "s1",
        "path" => "/name",
        "_target" => ["field1"],
        "field1" => "Alice"
      }

      assert {:noreply, updated_socket} = A2UI.Live.__handle_input_change__(params, socket)

      assert {:ok, "Alice"} =
               A2UI.DataModel.get(updated_socket.assigns.a2ui_surfaces["s1"].data_model, "/name")
    end
  end
end
