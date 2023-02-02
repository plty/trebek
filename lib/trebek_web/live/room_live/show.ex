defmodule TrebekWeb.RoomLive.DiscussionResponse do
  defstruct [:id, :prompt, :user, :content, :upvotes]
end

defmodule TrebekWeb.RoomLive.Show do
  use TrebekWeb, :live_view
  alias Uniq.UUID
  alias TrebekWeb.Presence

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    presence_topic = "Presence::RoomLive<#{room_id}>"

    if connected?(socket) do
      {:ok, _} =
        Presence.track(self(), presence_topic, socket.assigns.current_user.id, %{
          session: UUID.uuid7(),
          srv: Node.self()
        })

      Phoenix.PubSub.subscribe(Trebek.PubSub, presence_topic)
      Trebek.RoomDaemon.subscribe(room_id)
    end

    %{
      room: %{
        prompts_state: prompts_state,
        vote_count: vote_count,
        responses: {_, responses}
      },
      me: %{votes: user_votes, responses: user_responses}
    } = Trebek.RoomDaemon.snapshot(room_id, socket.assigns.current_user.id)

    [prompt] =
      case prompts_state.active do
        nil -> [nil]
        id -> prompts_state.prompts |> Enum.filter(fn e -> e.id === id end)
      end

    # TODO(optimize): check whether publishing the whole list or presence-diffs
    # on each socket is cheaper. pubsub is non-zero memory-cost operation in
    # erlang. try bench with thousands of user.
    {
      :ok,
      socket
      |> assign(:nodes, Enum.sort([Node.self() | Node.list(:visible)]))
      |> assign(:room_id, room_id)
      |> assign(:prompt, prompt)
      |> assign(:responses, responses |> Trbeek)
      |> assign(:users, %{} |> handle_diff(Presence.list(presence_topic), %{}))
    }

    # |> assign(:problem, Trebek.Credo.get({"room<#{room_id}>", :problem}))
    # |> assign(:responses, [])
    # |> assign(:users, %{} |> handle_diff(Presence.list(presence_topic), %{}))}
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
  def handle_info(%Trebek.RoomDaemon.Event{event: :prompts_state, payload: prompts_state}, socket) do
    [prompt] =
      case prompts_state.active do
        nil -> [nil]
        id -> prompts_state.prompts |> Enum.filter(fn e -> e.id === id end)
      end

    IO.inspect(["O.o", prompts_state])
    {:noreply, socket |> assign(prompt: prompt)}
  end

  @impl true
  def handle_info(
        %Trebek.RoomDaemon.Event{event: :vote_update, payload: %{vote_count: vote_count}},
        socket
      ) do
    IO.inspect(["o.O", vote_count])
    {:noreply, socket |> assign(vote_count: vote_count)}
  end

  @impl true
  def handle_info(%Aviato.Diffs{diffs: diffs}, socket) do
    IO.inspect(["O.o", diffs])
    {:noreply, socket}
  end

  @impl true
  def handle_info(info, socket) do
    IO.inspect(["o.o", info])
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit", %{"response" => %{"prompt" => p, "answer" => a}}, socket) do
    id = Uniq.UUID.uuid7()

    Trebek.Credo.put(
      {"room<#{socket.assigns.room_id}>", {:response, id}},
      %{
        prompt: p,
        response: a
      }
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
end
