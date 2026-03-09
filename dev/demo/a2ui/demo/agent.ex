defmodule A2UI.Demo.Agent do
  @moduledoc """
  Demo restaurant booking agent.

  A GenServer that sends A2UI protocol messages to connected LiveViews.
  Manages per-connection state and supports multiple simultaneous connections.
  """

  use GenServer

  alias A2UI.Component
  alias A2UI.Protocol.Messages.{CreateSurface, UpdateComponents, UpdateDataModel}

  # ── Client API ──

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  # ── GenServer callbacks ──

  @impl true
  def init(_) do
    {:ok, %{connections: %{}}}
  end

  @impl true
  def handle_info({:a2ui_connect, pid}, state) do
    Process.monitor(pid)
    send_booking_form(pid)
    {:noreply, put_in(state, [:connections, pid], :booking)}
  end

  def handle_info({:a2ui_action, action, metadata}, state) do
    pid = Map.get(metadata, :liveview_pid)

    case {action.name, pid} do
      {_, nil} ->
        {:noreply, state}

      {"submit_booking", pid} ->
        send_confirmation(pid, action.context)
        {:noreply, update_screen(state, pid, :confirmation)}

      {"new_reservation", pid} ->
        send_reset(pid)
        send_booking_form_components(pid)
        {:noreply, update_screen(state, pid, :booking)}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:a2ui_disconnect, pid}, state) do
    {:noreply, %{state | connections: Map.delete(state.connections, pid)}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | connections: Map.delete(state.connections, pid)}}
  end

  # ── Private ──

  defp update_screen(state, pid, screen) do
    put_in(state, [:connections, pid], screen)
  end

  defp send_booking_form(pid) do
    send(
      pid,
      {:a2ui_message,
       %CreateSurface{
         surface_id: "main",
         send_data_model: true,
         theme: %{primary_color: "#e65100"}
       }}
    )

    send(
      pid,
      {:a2ui_message,
       %UpdateDataModel{
         surface_id: "main",
         path: "/",
         value: %{
           "reservation" => %{
             "name" => "",
             "date" => "",
             "guests" => 2,
             "dietary" => []
           }
         },
         has_value: true
       }}
    )

    send_booking_form_components(pid)
  end

  defp send_booking_form_components(pid) do
    send(
      pid,
      {:a2ui_message,
       %UpdateComponents{
         surface_id: "main",
         components: booking_form_components()
       }}
    )
  end

  defp send_confirmation(pid, context) do
    name = Map.get(context, "name", "Guest")
    date = Map.get(context, "date", "Not specified")
    guests = Map.get(context, "guests", 2)
    dietary = Map.get(context, "dietary", [])

    dietary_text =
      case dietary do
        [] -> "None"
        list when is_list(list) -> Enum.join(list, ", ")
        other -> to_string(other)
      end

    send(
      pid,
      {:a2ui_message,
       %UpdateComponents{
         surface_id: "main",
         components: confirmation_components(name, date, guests, dietary_text)
       }}
    )
  end

  defp send_reset(pid) do
    send(
      pid,
      {:a2ui_message,
       %UpdateDataModel{
         surface_id: "main",
         path: "/",
         value: %{
           "reservation" => %{
             "name" => "",
             "date" => "",
             "guests" => 2,
             "dietary" => []
           }
         },
         has_value: true
       }}
    )
  end

  # ── Component definitions ──

  defp booking_form_components do
    [
      # Root
      %Component{
        id: "root",
        type: "Column",
        props: %{"children" => ["header", "booking-tabs", "cancellation-modal"]}
      },

      # Header
      %Component{
        id: "header",
        type: "Text",
        props: %{"text" => "Book Your Table", "variant" => "h1"}
      },

      # Tabs
      %Component{
        id: "booking-tabs",
        type: "Tabs",
        props: %{
          "tabItems" => [
            %{"title" => "Reservation", "child" => "form-card"},
            %{"title" => "Restaurant Info", "child" => "info-card"}
          ]
        }
      },

      # Card wrapper
      %Component{id: "form-card", type: "Card", props: %{"child" => "form-col"}},

      # Form column
      %Component{
        id: "form-col",
        type: "Column",
        props: %{
          "children" => [
            "name-field",
            "date-field",
            "guests-section",
            "dietary-section",
            "divider",
            "submit-row"
          ]
        }
      },

      # Name
      %Component{
        id: "name-field",
        type: "TextField",
        props: %{
          "label" => "Your Name",
          "value" => %{"path" => "/reservation/name"}
        }
      },

      # Date
      %Component{
        id: "date-field",
        type: "DateTimeInput",
        props: %{
          "label" => "Reservation Date",
          "value" => %{"path" => "/reservation/date"},
          "enableDate" => true
        }
      },

      # Guests section
      %Component{
        id: "guests-section",
        type: "Column",
        props: %{
          "children" => ["guests-label", "guests-slider", "guests-value"]
        }
      },
      %Component{
        id: "guests-label",
        type: "Text",
        props: %{"text" => "Number of Guests", "variant" => "body"}
      },
      %Component{
        id: "guests-slider",
        type: "Slider",
        props: %{
          "value" => %{"path" => "/reservation/guests"},
          "min" => 1,
          "max" => 12
        }
      },
      %Component{
        id: "guests-value",
        type: "Text",
        props: %{
          "text" => %{"path" => "/reservation/guests"},
          "variant" => "caption"
        }
      },

      # Dietary section
      %Component{
        id: "dietary-section",
        type: "Column",
        props: %{
          "children" => ["dietary-label", "dietary-picker"]
        }
      },
      %Component{
        id: "dietary-label",
        type: "Text",
        props: %{"text" => "Dietary Preferences", "variant" => "body"}
      },
      %Component{
        id: "dietary-picker",
        type: "ChoicePicker",
        props: %{
          "options" => [
            %{"label" => "Vegetarian", "value" => "vegetarian"},
            %{"label" => "Vegan", "value" => "vegan"},
            %{"label" => "Gluten-Free", "value" => "gluten-free"},
            %{"label" => "None", "value" => "none"}
          ],
          "selections" => %{"path" => "/reservation/dietary"},
          "maxAllowedSelections" => 0
        }
      },

      # Divider
      %Component{id: "divider", type: "Divider", props: %{"orientation" => "horizontal"}},

      # Submit row
      %Component{
        id: "submit-row",
        type: "Row",
        props: %{
          "children" => ["submit-btn"],
          "justify" => "end"
        }
      },
      %Component{
        id: "submit-btn",
        type: "Button",
        props: %{
          "child" => "submit-text",
          "variant" => "primary",
          "action" => %{
            "event" => %{
              "name" => "submit_booking",
              "context" => %{
                "name" => %{"path" => "/reservation/name"},
                "date" => %{"path" => "/reservation/date"},
                "guests" => %{"path" => "/reservation/guests"},
                "dietary" => %{"path" => "/reservation/dietary"}
              }
            }
          }
        }
      },
      %Component{
        id: "submit-text",
        type: "Text",
        props: %{"text" => "Reserve Table", "variant" => "body"}
      },

      # Restaurant info tab
      %Component{id: "info-card", type: "Card", props: %{"child" => "info-col"}},
      %Component{
        id: "info-col",
        type: "Column",
        props: %{
          "children" => ["info-name", "info-address", "info-hours", "info-desc"]
        }
      },
      %Component{
        id: "info-name",
        type: "Text",
        props: %{"text" => "The Golden Fork", "variant" => "h2"}
      },
      %Component{
        id: "info-address",
        type: "Text",
        props: %{"text" => "123 Dining Street, Stockholm", "variant" => "body"}
      },
      %Component{
        id: "info-hours",
        type: "Text",
        props: %{"text" => "Open daily 11:00–23:00", "variant" => "body"}
      },
      %Component{
        id: "info-desc",
        type: "Text",
        props: %{
          "text" => "Modern Nordic cuisine with a focus on locally sourced ingredients.",
          "variant" => "caption"
        }
      },

      # Cancellation policy modal
      %Component{
        id: "cancellation-modal",
        type: "Modal",
        props: %{
          "entryPointChild" => "cancellation-trigger",
          "contentChild" => "cancellation-content"
        }
      },
      %Component{
        id: "cancellation-trigger",
        type: "Button",
        props: %{
          "child" => "cancellation-trigger-text",
          "variant" => "borderless"
        }
      },
      %Component{
        id: "cancellation-trigger-text",
        type: "Text",
        props: %{"text" => "View Cancellation Policy", "variant" => "caption"}
      },
      %Component{
        id: "cancellation-content",
        type: "Column",
        props: %{
          "children" => [
            "cancellation-title",
            "cancellation-body",
            "cancellation-divider",
            "cancellation-note"
          ]
        }
      },
      %Component{
        id: "cancellation-title",
        type: "Text",
        props: %{"text" => "Cancellation Policy", "variant" => "h3"}
      },
      %Component{
        id: "cancellation-body",
        type: "Text",
        props: %{
          "text" =>
            "Reservations may be cancelled free of charge up to 24 hours before " <>
              "the scheduled time. Cancellations made within 24 hours may incur a " <>
              "fee of 200 SEK per guest. No-shows will be charged the full booking fee.",
          "variant" => "body"
        }
      },
      %Component{
        id: "cancellation-divider",
        type: "Divider",
        props: %{"orientation" => "horizontal"}
      },
      %Component{
        id: "cancellation-note",
        type: "Text",
        props: %{
          "text" => "Click outside this dialog to close.",
          "variant" => "caption"
        }
      }
    ]
  end

  defp confirmation_components(name, date, guests, dietary_text) do
    [
      # Root
      %Component{
        id: "root",
        type: "Column",
        props: %{"children" => ["header-row", "form-card"]}
      },

      # Header row with text + status badge
      %Component{
        id: "header-row",
        type: "Row",
        props: %{
          "children" => ["header", "status-badge"],
          "align" => "center"
        }
      },
      %Component{
        id: "header",
        type: "Text",
        props: %{"text" => "Reservation Confirmed!", "variant" => "h1"}
      },
      %Component{
        id: "status-badge",
        type: "StatusBadge",
        props: %{"status" => "confirmed"},
        accessibility: %{"label" => "Booking status: confirmed"}
      },

      # Card
      %Component{id: "form-card", type: "Card", props: %{"child" => "details-col"}},

      # Details
      %Component{
        id: "details-col",
        type: "Column",
        props: %{
          "children" => [
            "detail-name",
            "detail-date",
            "detail-guests",
            "detail-dietary",
            "divider",
            "new-row"
          ]
        }
      },
      %Component{
        id: "detail-name",
        type: "Text",
        props: %{"text" => "Name: #{name}", "variant" => "body"}
      },
      %Component{
        id: "detail-date",
        type: "Text",
        props: %{"text" => "Date: #{date}", "variant" => "body"}
      },
      %Component{
        id: "detail-guests",
        type: "Text",
        props: %{"text" => "Guests: #{guests}", "variant" => "body"}
      },
      %Component{
        id: "detail-dietary",
        type: "Text",
        props: %{"text" => "Dietary: #{dietary_text}", "variant" => "body"}
      },

      # Divider
      %Component{id: "divider", type: "Divider", props: %{"orientation" => "horizontal"}},

      # New reservation button
      %Component{
        id: "new-row",
        type: "Row",
        props: %{
          "children" => ["new-btn"],
          "justify" => "center"
        }
      },
      %Component{
        id: "new-btn",
        type: "Button",
        props: %{
          "child" => "new-text",
          "variant" => "default",
          "action" => %{
            "event" => %{
              "name" => "new_reservation",
              "context" => %{}
            }
          }
        }
      },
      %Component{
        id: "new-text",
        type: "Text",
        props: %{"text" => "New Reservation", "variant" => "body"}
      }
    ]
  end
end
