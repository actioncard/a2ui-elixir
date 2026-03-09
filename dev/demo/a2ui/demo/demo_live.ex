defmodule A2UI.Demo.DemoLive do
  use Phoenix.LiveView, layout: {A2UI.Demo.Layouts, :app}
  use A2UI.Live

  def mount(_params, _session, socket) do
    if connected?(socket) do
      {:ok, transport} = A2UI.Transport.Local.connect(agent: A2UI.Demo.Agent)
      {:ok, assign(socket, transport: transport)}
    else
      {:ok, assign(socket, transport: nil)}
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
    metadata = Map.put(metadata, :liveview_pid, self())
    A2UI.Transport.Local.send_action(socket.assigns.transport, action, metadata)
    {:noreply, socket}
  end
end
