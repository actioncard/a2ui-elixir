defmodule A2UI.Transport.SSETest do
  use ExUnit.Case, async: true

  alias A2UI.Transport.SSE

  test "deliver_message sends {:a2ui_deliver, msg} to pid" do
    assert :ok = SSE.deliver_message(self(), :test_msg)
    assert_received {:a2ui_deliver, :test_msg}
  end

  test "deliver_message sends struct messages" do
    msg = %A2UI.Protocol.Messages.CreateSurface{surface_id: "main", catalog_id: "basic"}
    assert :ok = SSE.deliver_message(self(), msg)
    assert_received {:a2ui_deliver, ^msg}
  end
end
