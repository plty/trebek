defmodule Trebek.Problem.MultipleChoice do
  defstruct [:q, :c]
end

defmodule Trebek.Problem.ShortAnswer do
  defstruct [:q]
end

defmodule TrebekWeb.RoomLive.Edit do
  use TrebekWeb, :live_view

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    {:ok, socket |> assign(room_id: room_id)}
  end

  @impl true
  def handle_event("save", %{"problem" => %{"question" => q}}, socket) do
    Trebek.Credo.put("problem:" <> socket.assigns.room_id, q)

    TrebekWeb.Endpoint.broadcast(
      "room:" <> socket.assigns.room_id,
      "question_changed",
      q
    )

    {:noreply, socket}
  end
end
