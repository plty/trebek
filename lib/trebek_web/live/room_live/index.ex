defmodule TrebekWeb.RoomLive.Index do
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
      TrebekWeb.Endpoint.subscribe("room:" <> room_id)
    end

    # TODO(optimize): check whether publishing the whole list or presence-diffs
    # on each socket is cheaper. pubsub is non-zero memory-cost operation in
    # erlang. try bench with thousands of user.
    {:ok,
     socket
     |> assign(:nodes, Enum.sort([Node.self() | Node.list(:visible)]))
     |> assign(:room_id, room_id)
     |> assign(:question, Trebek.Credo.get("problem:" <> room_id, nil))
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
  def handle_info(%{event: "question_changed", payload: q}, socket) do
    {:noreply, socket |> assign(:question, q)}
  end

  @impl true
  def handle_event("submit", %{"response" => %{"answer" => a}}, socket) do
    Trebek.Credo.put("answer:" <> socket.assigns.room_id <> ":" <> socket.assigns.current_user, a)

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
