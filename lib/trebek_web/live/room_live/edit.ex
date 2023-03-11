defmodule TrebekWeb.RoomLive.Edit do
  use TrebekWeb, :live_view

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    current_user = socket.assigns.current_user

    case Trebek.Credo.get({"room<#{room_id}>", :owner}) do
      ^current_user -> {:ok, socket |> assign(room_id: room_id)}
      _ -> {:ok, socket |> redirect(to: "/room")}
    end
  end

  @impl true
  def handle_event("save", %{"problem" => %{"question" => q}}, socket) do
    id = Uniq.UUID.uuid7()

    Trebek.Credo.put(
      {"room<#{socket.assigns.room_id}>", :prompts},
      %{
        active: id,
        can_answer: false,
        can_vote: false,
        prompts: [%{id: id, type: :discussion, title: q}]
      }
    )

    {:noreply, socket}
  end
end
