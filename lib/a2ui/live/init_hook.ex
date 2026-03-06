defmodule A2UI.Live.InitHook do
  @moduledoc """
  LiveView `on_mount` hook that initializes `@a2ui_surfaces` assign.
  """

  def on_mount(:default, _params, _session, socket) do
    {:cont, Phoenix.Component.assign_new(socket, :a2ui_surfaces, fn -> %{} end)}
  end
end
