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
    end

    # NOTE: notice subscribe is done before listing. structure has to be
    # idempotent

    # TODO(optimize): check whether pubsub-ing the whole list or presence-diffs
    # on each socket is cheaper. pubsub is non-zero memory-cost operation in
    # erlang. try bench with thousands of user.
    {:ok,
     socket
     |> assign(:nodes, Enum.sort([Node.self() | Node.list(:visible)]))
     |> assign(:question, Trebek.Credo.get("problem:" <> room_id, nil))
     |> assign(:current_user, id)
     |> assign(:users, %{} |> handle_joins(Presence.list(presence_id)))}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    users =
      socket.assigns.users
      |> handle_leaves(diff.leaves)
      |> handle_joins(diff.joins)

    IO.inspect(users)

    {
      :noreply,
      socket |> assign(:users, users)
    }
  end

  @impl true
  def handle_event("save", param, socket) do
    IO.inspect(param)
    IO.inspect(socket)
    {:noreply, socket}
  end

  # TODO(correctness): Make the map keyed by {username, session_id}, because
  # of session_id uniqueness, presence_diff joining should be trivial.
  defp handle_joins(state, joins) do
    joins =
      joins
      |> Enum.flat_map(fn {id, %{metas: metas}} ->
        metas
        |> Enum.map(fn
          %{session: session} = meta -> {{id, session}, meta}
        end)
      end)

    Map.merge(state, Map.new(joins))
  end

  defp handle_leaves(state, leaves) do
    leaves =
      leaves
      |> Enum.flat_map(fn {id, %{metas: metas}} ->
        metas
        |> Enum.map(fn
          %{session: session} -> {id, session}
        end)
      end)

    Map.drop(state, leaves)
  end
end
