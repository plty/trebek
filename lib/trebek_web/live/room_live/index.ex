defmodule TrebekWeb.RoomLive.Index do
  alias TrebekWeb.AuthController
  use TrebekWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("create-room", _params, socket) do
    case AuthController.is_guest?(socket.assigns.current_user.id) do
      true ->
        {:noreply, socket |> redirect(to: "/auth/login")}

      false ->
        room_id = Petname.gen()
        Trebek.Credo.put({"room<#{room_id}>", :owner}, socket.assigns.current_user)

        Horde.DynamicSupervisor.start_child(
          Trebek.DynamicSupervisor,
          {Trebek.RoomDaemon, room: room_id}
        )

        {:noreply, socket |> redirect(to: "/room/#{room_id}")}
    end
  end
end
