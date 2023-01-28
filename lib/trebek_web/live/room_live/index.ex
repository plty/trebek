defmodule TrebekWeb.RoomLive.Index do
  use TrebekWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("create-room", _params, socket) do
    petname = Petname.gen()

    Horde.DynamicSupervisor.start_child(
      Trebek.DynamicSupervisor,
      {Trebek.RoomDaemon, room: petname}
    )

    {:noreply, socket |> redirect(to: "/room/#{petname}")}
  end
end
