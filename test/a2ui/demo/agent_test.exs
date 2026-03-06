defmodule A2UI.Demo.AgentTest do
  use ExUnit.Case, async: true

  alias A2UI.Demo.Agent
  alias A2UI.Protocol.Messages.{CreateSurface, UpdateComponents, UpdateDataModel, Action}

  setup do
    {:ok, agent} = Agent.start_link()
    %{agent: agent}
  end

  describe "connect" do
    test "sends CreateSurface, UpdateDataModel, and UpdateComponents on connect", %{agent: agent} do
      send(agent, {:a2ui_connect, self()})

      assert_receive {:a2ui_message, %CreateSurface{surface_id: "main", send_data_model: true}}
      assert_receive {:a2ui_message, %UpdateDataModel{surface_id: "main", path: "/", has_value: true, value: value}}
      assert value["reservation"]["name"] == ""
      assert value["reservation"]["guests"] == 2
      assert value["reservation"]["dietary"] == []

      assert_receive {:a2ui_message, %UpdateComponents{surface_id: "main", components: components}}
      assert length(components) > 0

      # Verify root component exists
      root = Enum.find(components, &(&1.id == "root"))
      assert root.type == "Column"

      # Verify form fields exist
      name_field = Enum.find(components, &(&1.id == "name-field"))
      assert name_field.type == "TextField"

      submit_btn = Enum.find(components, &(&1.id == "submit-btn"))
      assert submit_btn.type == "Button"
      assert submit_btn.props["variant"] == "primary"
    end
  end

  describe "submit_booking action" do
    test "sends confirmation components", %{agent: agent} do
      send(agent, {:a2ui_connect, self()})
      flush_connect_messages()

      action = %Action{
        name: "submit_booking",
        surface_id: "main",
        source_component_id: "submit-btn",
        context: %{
          "name" => "Alice",
          "date" => "2026-03-15",
          "guests" => 4,
          "dietary" => ["vegetarian", "gluten-free"]
        }
      }

      send(agent, {:a2ui_action, action, %{liveview_pid: self()}})

      assert_receive {:a2ui_message, %UpdateComponents{components: components}}

      header = Enum.find(components, &(&1.id == "header"))
      assert header.props["text"] == "Reservation Confirmed!"

      name_detail = Enum.find(components, &(&1.id == "detail-name"))
      assert name_detail.props["text"] == "Name: Alice"

      guests_detail = Enum.find(components, &(&1.id == "detail-guests"))
      assert guests_detail.props["text"] == "Guests: 4"

      dietary_detail = Enum.find(components, &(&1.id == "detail-dietary"))
      assert dietary_detail.props["text"] == "Dietary: vegetarian, gluten-free"
    end
  end

  describe "new_reservation action" do
    test "resets data model and sends booking form", %{agent: agent} do
      send(agent, {:a2ui_connect, self()})
      flush_connect_messages()

      # Submit first
      submit = %Action{
        name: "submit_booking",
        surface_id: "main",
        source_component_id: "submit-btn",
        context: %{"name" => "Bob", "date" => "", "guests" => 2, "dietary" => []}
      }

      send(agent, {:a2ui_action, submit, %{liveview_pid: self()}})
      assert_receive {:a2ui_message, %UpdateComponents{}}

      # Then new reservation
      new_res = %Action{
        name: "new_reservation",
        surface_id: "main",
        source_component_id: "new-btn",
        context: %{}
      }

      send(agent, {:a2ui_action, new_res, %{liveview_pid: self()}})

      assert_receive {:a2ui_message, %UpdateDataModel{path: "/", has_value: true, value: value}}
      assert value["reservation"]["name"] == ""
      assert value["reservation"]["guests"] == 2

      assert_receive {:a2ui_message, %UpdateComponents{components: components}}
      header = Enum.find(components, &(&1.id == "header"))
      assert header.props["text"] == "Book Your Table"
    end
  end

  describe "disconnect" do
    test "agent stays alive after disconnect", %{agent: agent} do
      send(agent, {:a2ui_connect, self()})
      flush_connect_messages()

      send(agent, {:a2ui_disconnect, self()})
      # Small delay to let the message process
      Process.sleep(10)
      assert Process.alive?(agent)
    end
  end

  describe "DOWN monitor" do
    test "cleans up connection on monitored process exit", %{agent: agent} do
      # Spawn a temporary process to connect
      task =
        Task.async(fn ->
          send(agent, {:a2ui_connect, self()})
          receive do: (_ -> :ok)
        end)

      # Let it connect
      Process.sleep(10)
      # Kill the task
      Task.shutdown(task, :brutal_kill)
      # Agent should still be alive
      Process.sleep(10)
      assert Process.alive?(agent)
    end
  end

  describe "multiple connections" do
    test "handles independent connections", %{agent: agent} do
      # Connect from this process
      send(agent, {:a2ui_connect, self()})
      assert_receive {:a2ui_message, %CreateSurface{}}
      assert_receive {:a2ui_message, %UpdateDataModel{}}
      assert_receive {:a2ui_message, %UpdateComponents{}}

      # Spawn another connection
      parent = self()

      spawn(fn ->
        send(agent, {:a2ui_connect, self()})
        assert_receive {:a2ui_message, %CreateSurface{}}
        assert_receive {:a2ui_message, %UpdateDataModel{}}
        assert_receive {:a2ui_message, %UpdateComponents{}}
        send(parent, :second_connected)
      end)

      assert_receive :second_connected
    end
  end

  defp flush_connect_messages do
    assert_receive {:a2ui_message, %CreateSurface{}}
    assert_receive {:a2ui_message, %UpdateDataModel{}}
    assert_receive {:a2ui_message, %UpdateComponents{}}
  end
end
