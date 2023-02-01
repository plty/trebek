defmodule Trebek.Show.Freq do
  defstruct [:id, :resp, :freq]
end

defmodule TrebekWeb.RoomLive.Show do
  use TrebekWeb, :live_view
  alias Uniq.UUID
  alias TrebekWeb.Presence

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    presence_id = "presence:room:" <> room_id

    unless Trebek.Credo.get({"room<#{room_id}>", :owner}) do
      {:ok, socket |> redirect(to: "/room")}
    else
      if connected?(socket) do
        {:ok, _} =
          Presence.track(self(), presence_id, socket.assigns.current_user.id, %{
            session: UUID.uuid7(),
            srv: Node.self()
          })

        Phoenix.PubSub.subscribe(Trebek.PubSub, presence_id)
        Trebek.RoomDaemon.subscribe(room_id)
        TrebekWeb.Endpoint.subscribe("room:" <> room_id <> ":response")
      end

      # TODO(optimize): check whether publishing the whole list or presence-diffs
      # on each socket is cheaper. pubsub is non-zero memory-cost operation in
      # erlang. try bench with thousands of user.
      {:ok,
       socket
       |> assign(:nodes, Enum.sort([Node.self() | Node.list(:visible)]))
       |> assign(:room_id, room_id)
       |> assign(:question, Trebek.Credo.get({"room<#{room_id}>", :problem}))
       |> assign(:users, %{} |> handle_diff(Presence.list(presence_id), %{}))
       |> assign(:responses, get_responses(room_id))}
    end
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
        %Trebek.RoomDaemon.Event{event: :prompt_update, payload: %{problem: problem}},
        socket
      ) do
    IO.inspect(["O.o", problem])
    {:noreply, socket |> assign(question: problem)}
  end

  @impl true
  def handle_info(%Aviato.Diffs{diffs: diffs}, socket) do
    IO.inspect(["O.o", diffs])
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: "response_changed", payload: r}, socket) do
    {:noreply, socket |> assign(:responses, r)}
  end

  @impl true
  def handle_event("upvote", %{"response" => id}, socket) do
    Trebek.Credo.put(
      {"room<#{socket.assigns.room_id}>vote", {id, socket.assigns.current_user.id}},
      1
    )

    TrebekWeb.Endpoint.broadcast(
      "room:" <> socket.assigns.room_id <> ":response",
      "response_changed",
      get_responses(socket.assigns.room_id)
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("submit", %{"response" => %{"answer" => a}}, socket) do
    resp_id = UUID.uuid7()
    Trebek.Credo.put({"room<#{socket.assigns.room_id}>response", resp_id}, a)

    Trebek.Credo.put(
      {"room<#{socket.assigns.room_id}>vote", {resp_id, socket.assigns.current_user.id}},
      1
    )

    TrebekWeb.Endpoint.broadcast(
      "room:" <> socket.assigns.room_id <> ":response",
      "response_changed",
      get_responses(socket.assigns.room_id)
    )

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

  def get_responses(room_id) do
    :maps.filter(
      fn {topic, _id}, _y ->
        topic == "room<#{room_id}>vote"
      end,
      Trebek.Credo.get()
    )
    |> Enum.map(fn {{_topic, {id, _uid}}, _y} -> id end)
    |> Enum.frequencies()
    |> Map.to_list()
    |> Enum.map(fn {x, y} ->
      %Trebek.Show.Freq{id: x, freq: y, resp: Trebek.Credo.get({"room<#{room_id}>response", x})}
    end)
    |> Enum.sort(fn l, r -> l.freq > r.freq end)
  end
end
