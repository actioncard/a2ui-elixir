defmodule A2UI.Protocol.MessagesTest do
  use ExUnit.Case, async: true

  alias A2UI.Protocol.Message

  alias A2UI.Protocol.Messages.{
    Action,
    CreateSurface,
    DeleteSurface,
    UpdateComponents,
    UpdateDataModel
  }

  @fixtures_path "test/support/fixtures"

  defp load_fixture(name) do
    @fixtures_path
    |> Path.join(name)
    |> File.read!()
  end

  describe "CreateSurface" do
    test "parses from JSON fixture" do
      json = load_fixture("create_surface.json")
      assert {:ok, %CreateSurface{} = msg} = Message.from_json(json)

      assert msg.surface_id == "main"
      assert msg.catalog_id == "https://a2ui.org/specification/v0_9/basic_catalog.json"
      assert msg.theme.primary_color == "#1a73e8"
      assert msg.theme.icon_url == "https://example.com/icon.png"
      assert msg.theme.agent_display_name == "My Agent"
      assert msg.send_data_model == true
    end

    test "defaults send_data_model to false" do
      {:ok, msg} =
        Message.from_map(%{
          "version" => "v0.9",
          "createSurface" => %{
            "surfaceId" => "s1",
            "catalogId" => "test"
          }
        })

      assert msg.send_data_model == false
    end
  end

  describe "UpdateComponents" do
    test "parses from JSON fixture" do
      json = load_fixture("update_components.json")
      assert {:ok, %UpdateComponents{} = msg} = Message.from_json(json)

      assert msg.surface_id == "main"
      assert length(msg.components) == 3

      [root, header, card] = msg.components
      assert root.id == "root"
      assert root.type == "Column"
      assert root.props["children"] == ["header", "form-card"]
      assert root.props["align"] == "stretch"

      assert header.id == "header"
      assert header.type == "Text"
      assert header.props["text"] == "# Book Your Table"

      assert card.id == "form-card"
      assert card.type == "Card"
      assert card.props["child"] == "form-column"
    end
  end

  describe "UpdateDataModel" do
    test "parses from JSON fixture" do
      json = load_fixture("update_data_model.json")
      assert {:ok, %UpdateDataModel{} = msg} = Message.from_json(json)

      assert msg.surface_id == "main"
      assert msg.path == "/reservation"
      assert msg.value == %{"date" => "2025-12-15", "time" => "19:00", "guests" => 2}
    end

    test "defaults path to /" do
      {:ok, msg} =
        Message.from_map(%{
          "version" => "v0.9",
          "updateDataModel" => %{"surfaceId" => "s1"}
        })

      assert msg.path == "/"
    end
  end

  describe "DeleteSurface" do
    test "parses from map" do
      {:ok, msg} =
        Message.from_map(%{
          "version" => "v0.9",
          "deleteSurface" => %{"surfaceId" => "main"}
        })

      assert %DeleteSurface{surface_id: "main"} = msg
    end
  end

  describe "Action" do
    test "parses client action" do
      {:ok, msg} =
        Message.from_map(%{
          "name" => "confirm_booking",
          "surfaceId" => "main",
          "sourceComponentId" => "submit-btn",
          "timestamp" => "2025-12-15T10:30:00Z",
          "context" => %{"date" => "2025-12-15"}
        })

      assert %Action{} = msg
      assert msg.name == "confirm_booking"
      assert msg.surface_id == "main"
      assert msg.source_component_id == "submit-btn"
      assert msg.timestamp == "2025-12-15T10:30:00Z"
      assert msg.context == %{"date" => "2025-12-15"}
    end
  end

  describe "CreateSurface.to_map/1" do
    test "round-trips full message" do
      original = %CreateSurface{
        surface_id: "main",
        catalog_id: "test-catalog",
        theme: %{
          primary_color: "#1a73e8",
          icon_url: "https://example.com/icon.png",
          agent_display_name: "Agent"
        },
        send_data_model: true
      }

      assert original == original |> CreateSurface.to_map() |> CreateSurface.from_map()
    end

    test "omits theme when all nil and sendDataModel when false" do
      msg = %CreateSurface{
        surface_id: "s1",
        catalog_id: "c1",
        theme: %{primary_color: nil, icon_url: nil, agent_display_name: nil},
        send_data_model: false
      }

      map = CreateSurface.to_map(msg)
      refute Map.has_key?(map, "theme")
      refute Map.has_key?(map, "sendDataModel")
    end
  end

  describe "UpdateComponents.to_map/1" do
    test "round-trips with multiple components" do
      original = %UpdateComponents{
        surface_id: "main",
        components: [
          %A2UI.Component{
            id: "root",
            type: "Column",
            props: %{"children" => ["h1"]}
          },
          %A2UI.Component{
            id: "h1",
            type: "Text",
            props: %{"text" => "Hello"}
          }
        ]
      }

      assert original ==
               original |> UpdateComponents.to_map() |> UpdateComponents.from_map()
    end
  end

  describe "UpdateDataModel.to_map/1" do
    test "round-trips with value (set)" do
      original = %UpdateDataModel{
        surface_id: "main",
        path: "/name",
        value: "Alice",
        has_value: true
      }

      assert original ==
               original |> UpdateDataModel.to_map() |> UpdateDataModel.from_map()
    end

    test "round-trips without value (delete)" do
      original = %UpdateDataModel{
        surface_id: "main",
        path: "/name",
        value: nil,
        has_value: false
      }

      result = original |> UpdateDataModel.to_map() |> UpdateDataModel.from_map()
      assert result == original
      refute Map.has_key?(UpdateDataModel.to_map(original), "value")
    end
  end

  describe "DeleteSurface.to_map/1" do
    test "round-trips" do
      original = %DeleteSurface{surface_id: "main"}

      assert original ==
               original |> DeleteSurface.to_map() |> DeleteSurface.from_map()
    end
  end

  describe "Action.to_map/1" do
    test "round-trips full action" do
      original = %Action{
        name: "submit",
        surface_id: "main",
        source_component_id: "btn",
        timestamp: "2025-12-15T10:30:00Z",
        context: %{"key" => "val"}
      }

      assert original == original |> Action.to_map() |> Action.from_map()
    end

    test "omits timestamp when nil and context when empty" do
      msg = %Action{
        name: "submit",
        surface_id: "main",
        source_component_id: "btn",
        timestamp: nil,
        context: %{}
      }

      map = Action.to_map(msg)
      refute Map.has_key?(map, "timestamp")
      refute Map.has_key?(map, "context")
    end
  end

  describe "Message.to_map/1" do
    test "wraps server messages with version" do
      msg = %CreateSurface{
        surface_id: "s1",
        catalog_id: "c1",
        theme: %{primary_color: nil, icon_url: nil, agent_display_name: nil}
      }

      map = Message.to_map(msg)
      assert map["version"] == "v0.9"
      assert map["createSurface"]["surfaceId"] == "s1"
    end

    test "does not wrap Action with version" do
      msg = %Action{
        name: "x",
        surface_id: "s1",
        source_component_id: "c1"
      }

      map = Message.to_map(msg)
      refute Map.has_key?(map, "version")
      assert map["name"] == "x"
    end

    test "full round-trip through Message dispatcher" do
      msgs = [
        %CreateSurface{
          surface_id: "s1",
          catalog_id: "c1",
          theme: %{
            primary_color: "#fff",
            icon_url: nil,
            agent_display_name: nil
          },
          send_data_model: true
        },
        %UpdateComponents{
          surface_id: "s1",
          components: [
            %A2UI.Component{id: "r", type: "Row", props: %{}}
          ]
        },
        %UpdateDataModel{
          surface_id: "s1",
          path: "/x",
          value: 42,
          has_value: true
        },
        %DeleteSurface{surface_id: "s1"},
        %Action{
          name: "go",
          surface_id: "s1",
          source_component_id: "btn",
          timestamp: "2025-01-01T00:00:00Z",
          context: %{"a" => 1}
        }
      ]

      for original <- msgs do
        assert {:ok, ^original} =
                 original |> Message.to_map() |> Message.from_map()
      end
    end
  end

  describe "Message.to_json/1" do
    test "encode and decode round-trip" do
      original = %CreateSurface{
        surface_id: "s1",
        catalog_id: "c1",
        theme: %{
          primary_color: nil,
          icon_url: nil,
          agent_display_name: nil
        }
      }

      assert {:ok, json} = Message.to_json(original)
      assert {:ok, ^original} = Message.from_json(json)
    end
  end

  describe "error handling" do
    test "unknown version" do
      assert {:error, "unsupported protocol version: v0.1"} =
               Message.from_map(%{"version" => "v0.1", "createSurface" => %{}})
    end

    test "unknown message format" do
      assert {:error, "unknown message format"} = Message.from_map(%{"foo" => "bar"})
    end

    test "invalid JSON" do
      assert {:error, "JSON decode error:" <> _} = Message.from_json("not json")
    end
  end
end
