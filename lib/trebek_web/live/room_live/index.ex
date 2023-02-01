defmodule TrebekWeb.RoomLive.Index do
  use TrebekWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("create-room", _params, socket) do
    room_id = Petname.gen()
    Trebek.Credo.put({"room<#{room_id}>", :owner}, socket.assigns.current_user)

    Horde.DynamicSupervisor.start_child(
      Trebek.DynamicSupervisor,
      {Trebek.RoomDaemon, room: room_id}
    )

    {:noreply, socket |> redirect(to: "/room/#{room_id}")}
  end

  @impl true
  def handle_event("go", %{"room" => %{"room_id" => id}}, socket) do
    {:noreply, socket |> redirect(to: "/room/" <> id)}
  end
end
