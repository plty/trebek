defmodule TrebekWeb.RoomLive.Edit do
  use TrebekWeb, :live_view

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Trebek.RoomDaemon.subscribe(room_id)
    end

    case Trebek.Credo.get({"room<#{room_id}>", :owner}) do
      ^current_user ->
        {:ok,
         socket
         |> assign(
           room_id: room_id,
           prompts_state:
             Trebek.Credo.get({"room<#{room_id}>", :prompts}) || %{active: nil, prompts: []}
         )}

      _ ->
        {:ok, socket |> redirect(to: ~p"/room")}
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

  @impl true
  def handle_event("add-prompt", _, socket) do
    ps = socket.assigns.prompts_state
    id = Uniq.UUID.uuid7()

    Trebek.Credo.put(
      {"room<#{socket.assigns.room_id}>", :prompts},
      %{
        active: ps.active,
        prompts: [%{id: id, type: :discussion, title: "ayo apa hayo"} | ps.prompts]
      }
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info(%Trebek.RoomDaemon.Event{event: :prompts_state, payload: prompts_state}, socket) do
    {:noreply, socket |> assign(prompts_state: prompts_state)}
  end

  @impl true
  def handle_info(%Trebek.RoomDaemon.Event{}, socket) do
    {:noreply, socket}
  end
end
