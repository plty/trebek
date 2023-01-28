defmodule TrebekWeb.RoomLive.Show do
  use TrebekWeb, :live_view
  alias Uniq.UUID
  alias TrebekWeb.Presence

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    presence_id = "presence:room:" <> room_id
    id = UUID.uuid7()

    if connected?(socket) do
      {:ok, _} =
        Presence.track(self(), presence_id, id, %{
          session: UUID.uuid7(),
          srv: Node.self()
        })

      Phoenix.PubSub.subscribe(Trebek.PubSub, presence_id)
      Trebek.RoomDaemon.subscribe(room_id)
    end

    # TODO(optimize): check whether publishing the whole list or presence-diffs
    # on each socket is cheaper. pubsub is non-zero memory-cost operation in
    # erlang. try bench with thousands of user.
    {:ok,
     socket
     |> assign(:nodes, Enum.sort([Node.self() | Node.list(:visible)]))
     |> assign(:room_id, room_id)
     |> assign(:question, Trebek.Credo.get({"room<#{room_id}>", :problem}))
     |> assign(:current_user, id)
     |> assign(:users, %{} |> handle_diff(Presence.list(presence_id), %{}))}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    {
      :noreply,
      socket
      |> assign(
        :users,
        socket.assigns.users
        |> handle_diff(diff.joins, diff.leaves)
      )
    }
  end

  @impl true
  def handle_info(
        %Trebek.RoomDaemon.Event{event: :problem_update, payload: %{problem: problem}},
        socket
      ) do
    IO.inspect(["O.o", problem])
    {:noreply, socket |> assign(question: problem)}
  end

  @impl true
  def handle_info(%Aviato.DeltaCrdt.Diffs{diffs: diffs}, socket) do
    IO.inspect(["O.o", diffs])
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit", %{"response" => %{"answer" => a}}, socket) do
    Trebek.Credo.put("answer." <> socket.assigns.room_id, a)

    {:noreply, socket}
  end

  defp handle_diff(state, joins, leaves) do
    joins =
      joins
      |> Enum.flat_map(fn {id, %{metas: metas}} ->
        metas
        |> Enum.map(fn
          %{session: session} = meta -> {{id, session}, meta}
        end)
      end)

    leaves =
      leaves
      |> Enum.flat_map(fn {id, %{metas: metas}} ->
        metas
        |> Enum.map(fn
          %{session: session} -> {id, session}
        end)
      end)

    state
    |> Map.merge(Map.new(joins))
    |> Map.drop(leaves)
  end
end
