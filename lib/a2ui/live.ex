defmodule A2UI.Live do
  @moduledoc """
  Macro for integrating A2UI into a Phoenix LiveView.

  Add `use A2UI.Live` to your LiveView module to get:

  - `@a2ui_surfaces` assign initialized via `on_mount`
  - Automatic handling of `{:a2ui_message, msg}` info messages
  - Automatic handling of `a2ui_action` and `a2ui_input_change` events
  - A `handle_a2ui_action/3` callback for your action logic

  ## Example

      defmodule MyAppWeb.DemoLive do
        use MyAppWeb, :live_view
        use A2UI.Live

        def mount(_params, _session, socket) do
          # connect to an agent and start receiving messages
          {:ok, socket}
        end

        @impl A2UI.Live
        def handle_a2ui_action(action, metadata, socket) do
          # handle user actions from A2UI components
          {:noreply, socket}
        end
      end
  """

  alias A2UI.Live.EventHandler
  alias A2UI.SurfaceManager

  require Logger

  @callback handle_a2ui_action(
              action :: A2UI.Protocol.Messages.Action.t(),
              metadata :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {:noreply, Phoenix.LiveView.Socket.t()}

  @callback handle_a2ui_error(
              error :: A2UI.Protocol.Messages.Error.t(),
              metadata :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {:noreply, Phoenix.LiveView.Socket.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour A2UI.Live

      require Logger

      import A2UI.Components.Renderer, only: [surface: 1]

      on_mount(A2UI.Live.InitHook)

      @impl Phoenix.LiveView
      def handle_info({:a2ui_message, msg}, socket) do
        A2UI.Live.__handle_message__(msg, socket)
      end

      def handle_info({:a2ui_transport_error, reason}, socket) do
        Logger.error("A2UI transport error: #{inspect(reason)}")
        {:noreply, socket}
      end

      @impl Phoenix.LiveView
      def handle_event("a2ui_action", params, socket) do
        A2UI.Live.__handle_action__(params, socket, &handle_a2ui_action/3)
      end

      def handle_event("a2ui_input_change", params, socket) do
        A2UI.Live.__handle_input_change__(params, socket)
      end

      def handle_event("a2ui_error", params, socket) do
        A2UI.Live.__handle_error__(params, socket, &handle_a2ui_error/3)
      end

      def handle_event("a2ui_form_submit", _params, socket) do
        {:noreply, socket}
      end

      @impl A2UI.Live
      def handle_a2ui_action(_action, _metadata, socket) do
        Logger.warning("Unhandled A2UI action — override handle_a2ui_action/3")
        {:noreply, socket}
      end

      @impl A2UI.Live
      def handle_a2ui_error(_error, _metadata, socket) do
        Logger.warning("Unhandled A2UI error — override handle_a2ui_error/3")
        {:noreply, socket}
      end

      defoverridable handle_a2ui_action: 3,
                     handle_a2ui_error: 3,
                     handle_info: 2,
                     handle_event: 3
    end
  end

  @doc false
  def __handle_message__(msg, socket) do
    surfaces = socket.assigns[:a2ui_surfaces] || %{}

    case SurfaceManager.apply_message(surfaces, msg) do
      {:ok, updated} ->
        {:noreply, Phoenix.Component.assign(socket, :a2ui_surfaces, updated)}

      {:error, reason} ->
        Logger.error("A2UI message error: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @doc false
  def __handle_action__(params, socket, callback) do
    surfaces = socket.assigns[:a2ui_surfaces] || %{}

    case EventHandler.build_action(params, surfaces) do
      {:ok, action, metadata} ->
        callback.(action, metadata, socket)

      {:error, reason} ->
        Logger.error("A2UI action error: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @doc false
  def __handle_error__(params, socket, callback) do
    case EventHandler.build_error(params) do
      {:ok, error, metadata} ->
        callback.(error, metadata, socket)

      {:error, reason} ->
        Logger.error("A2UI error handling error: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @doc false
  def __handle_input_change__(params, socket) do
    surfaces = socket.assigns[:a2ui_surfaces] || %{}

    case EventHandler.apply_input_change(params, surfaces) do
      {:ok, updated} ->
        {:noreply, Phoenix.Component.assign(socket, :a2ui_surfaces, updated)}

      {:error, reason} ->
        Logger.error("A2UI input change error: #{inspect(reason)}")
        {:noreply, socket}
    end
  end
end
