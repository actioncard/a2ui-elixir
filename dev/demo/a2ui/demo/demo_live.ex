defmodule A2UI.Demo.DemoLive do
  use Phoenix.LiveView, layout: {A2UI.Demo.Layouts, :app}
  use A2UI.Live

  def mount(_params, _session, socket) do
    if connected?(socket) do
      {:ok, transport} = A2UI.Transport.Local.connect(agent: A2UI.Demo.Agent)
      {:ok, assign(socket, a2ui_transport: transport)}
    else
      {:ok, assign(socket, a2ui_transport: nil)}
    end
  end

  def render(assigns) do
    ~H"""
    <.surface :for={{_id, s} <- @a2ui_surfaces} surface={s} />
    <p :if={map_size(@a2ui_surfaces) == 0} style="text-align:center;color:#999;padding:2rem;">
      Connecting to agent...
    </p>
    """
  end

  @impl A2UI.Live
  def handle_a2ui_action(action, metadata, socket) do
    A2UI.Transport.send_action(socket.assigns.a2ui_transport, action, metadata)
    {:noreply, socket}
  end
end
