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
             Trebek.Credo.get({"room<#{room_id}>", :prompts}) ||
               %{active: nil, prompts: [], can_vote: false, can_answer: false}
         )}

      _ ->
        {:ok, socket |> redirect(to: ~p"/room")}
    end
  end

  @impl true
  def handle_event("save", %{"prompt" => %{"id" => id, "question" => q}}, socket) do
    ps = socket.assigns.prompts_state

    Trebek.Credo.put(
      {"room<#{socket.assigns.room_id}>", :prompts},
      %{
        ps
        | prompts:
            ps.prompts
            |> Enum.map(fn prompt ->
              case prompt.id do
                ^id -> %{prompt | title: q}
                _ -> prompt
              end
            end)
      }
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("activate", %{"id" => prompt_id}, socket) do
    Trebek.Credo.put(
      {"room<#{socket.assigns.room_id}>", :prompts},
      %{socket.assigns.prompts_state | active: prompt_id}
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
        ps
        | prompts: [%{id: id, type: :discussion, title: "ayo apa hayo"} | ps.prompts]
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
