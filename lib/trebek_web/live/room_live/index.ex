defmodule TrebekWeb.RoomLive.Index do
  use TrebekWeb, :live_view
  alias Uniq.UUID
  alias TrebekWeb.Presence

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    presence_id = "room:" <> room_id
    id = UUID.uuid7()

    if connected?(socket) do
      {:ok, _} =
        Presence.track(self(), presence_id, id, %{
          srv: Node.self()
        })

      Phoenix.PubSub.subscribe(Trebek.PubSub, presence_id)
    end

    {:ok,
     socket
     |> assign(:nodes, Enum.sort([Node.self() | Node.list(:visible)]))
     |> assign(:current_user, id)
     |> assign(:users, %{})
     |> handle_joins(Presence.list(presence_id))}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    {
      :noreply,
      socket
      |> handle_leaves(diff.leaves)
      |> handle_joins(diff.joins)
    }
  end

  defp handle_joins(socket, joins) do
    IO.inspect(socket)

    Enum.reduce(joins, socket, fn {user, %{metas: [meta | _]}}, socket ->
      assign(socket, :users, Map.put(socket.assigns.users, user, meta))
    end)
  end

  defp handle_leaves(socket, leaves) do
    Enum.reduce(leaves, socket, fn {user, _}, socket ->
      assign(socket, :users, Map.delete(socket.assigns.users, user))
    end)
  end
end
