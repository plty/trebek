defmodule TrebekWeb.RoomLive.DiscussionResponse do
  defstruct [:id, :prompt, :user, :content, :upvotes, :hidden]
end

defmodule TrebekWeb.RoomLive.Show do
  use TrebekWeb, :live_view
  alias Uniq.UUID
  alias TrebekWeb.Presence
  alias TrebekWeb.RoomLive.DiscussionResponse

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

    IO.inspect(["responses", responses])
    IO.inspect(["bebong", Trebek.Credo.get()])

    # TODO(optimize): check whether publishing the whole list or presence-diffs
    # on each socket is cheaper. pubsub is non-zero memory-cost operation in
    # erlang. try bench with thousands of user.
    {
      :ok,
      socket
      |> assign(:nodes, Enum.sort([Node.self() | Node.list(:visible)]))
      |> assign(:room_id, room_id)
      |> assign(:room_owner, Trebek.Credo.get({"room<#{room_id}>", :owner}))
      |> assign(
        prompt: prompt,
        can_vote: prompts_state.can_vote,
        can_answer: prompts_state.can_answer
      )
      |> assign(
        :responses,
        responses
        |> Enum.map(fn r ->
          %DiscussionResponse{
            id: r.id,
            prompt: r.prompt,
            user: r.user,
            content: r.content,
            upvotes: vote_count |> Map.get(r.id, 0),
            hidden: r.hidden
          }
        end)
      )
      |> assign(:vote_count, vote_count)
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

    {:noreply,
     socket
     |> assign(
       prompt: prompt,
       can_vote: prompts_state.can_vote,
       can_answer: prompts_state.can_answer
     )}
  end

  @impl true
  def handle_info(%Trebek.RoomDaemon.Event{event: :responses, payload: {_, responses}}, socket) do
    IO.inspect(["notresponses", responses])

    {:noreply,
     socket
     |> assign(
       responses:
         responses
         |> Enum.map(fn r ->
           %DiscussionResponse{
             id: r.id,
             prompt: r.prompt,
             user: r.user,
             content: r.content,
             upvotes: socket.assigns.vote_count |> Map.get(r.id, 0),
             hidden: r.hidden
           }
         end)
     )}
  end

  @impl true
  def handle_info(
        %Trebek.RoomDaemon.Event{event: :vote_count, payload: vote_count},
        socket
      ) do
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
  def handle_event("submit", %{"response" => %{"content" => content}}, socket) do
    current_user = socket.assigns.current_user
    current_user_id = current_user.id

    Trebek.Credo.put(
      {"room<#{socket.assigns.room_id}>", {:responses, current_user_id}},
      [
        %{
          id: Uniq.UUID.uuid7(),
          prompt: socket.assigns.prompt.id,
          user: current_user_id,
          content: content,
          hidden: false
        }
        | socket.assigns.responses
          |> Enum.flat_map(fn r ->
            case r.user do
              ^current_user_id ->
                [
                  %{
                    id: r.id,
                    prompt: r.prompt,
                    user: r.user,
                    content: r.content,
                    hidden: r.hidden
                  }
                ]

              _ ->
                []
            end
          end)
      ]
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("upvote", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user
    current_user_id = current_user.id

    Trebek.Credo.put(
      {"room<#{socket.assigns.room_id}>", {:votes, current_user_id}},
      [
        id
        | Trebek.Credo.get({"room<#{socket.assigns.room_id}>", {:votes, current_user_id}}) || []
      ]
      |> Enum.uniq()
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
