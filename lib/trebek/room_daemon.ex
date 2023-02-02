defmodule Trebek.RoomDaemon.Event do
  defstruct [:event, :payload]
end

defmodule Trebek.RoomDaemon do
  use GenServer

  def start_link(opts) do
    opts = opts |> Enum.into(%{})

    case GenServer.start_link(__MODULE__, opts, name: via_tuple(opts[:room])) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, _pid}} -> :ignore
      v -> v
    end
  end

  def subscribe(room) do
    Phoenix.PubSub.subscribe(Trebek.PubSub, "#{__MODULE__}<#{room}>")
  end

  def snapshot(room, user) do
    GenServer.call(via_tuple(room), {:snapshot, user})
  end

  def via_tuple(room), do: {:via, Horde.Registry, {Trebek.Registry, "#{__MODULE__}<#{room}>"}}

  @impl true
  def init(opts) do
    IO.puts("INITIATEDDD")
    %{room: room} = opts |> Enum.into(%{})
    topic = "room<#{room}>"

    {:ok,
     %{
       room: room,
       topic: topic
     }, {:continue, :init}}
  end

  def multisplit(m, f) do
    m
    |> Enum.reduce(
      %{},
      fn e, acc -> Map.update(acc, f.(e), [e], fn es -> [e | es] end) end
    )
    |> Enum.map(fn {k, vs} -> {k, vs |> Enum.reverse()} end)
    |> Map.new()
  end

  @typep incomplete_state() ::
           %{
             room: String.t(),
             topic: String.t()
           }

  @typep prompt() ::
           %{id: UUID.Uniq.t(), type: :mcq, question: String.t()}
           | %{id: UUID.Uniq.t(), type: :discussion, title: String.t()}

  @typep response() :: %{
           id: UUID.Uniq.t(),
           prompt: UUID.Uniq.t(),
           user: UUID.Uniq.t(),
           content: String.t()
         }

  @typep state() ::
           %{
             room: String.t(),
             topic: String.t(),
             prompts_state: %{
               active: nil | Uniq.UUID.t(),
               prompts: [prompt()]
             },
             votes_state: %{
               votes: %{Uniq.UUID.t() => [Uniq.UUID.t()]},
               vote_count: %{Uniq.UUID.t() => [Uniq.UUID.t()]}
             },
             responses_state: %{
               responses_by_user: %{},
               responses_by_prompt: %{Uniq.UUID.t() => [response()]}
             }
           }

  @impl true
  @spec handle_continue(:init, incomplete_state()) :: {:noreply, state()}
  def handle_continue(:init, state) do
    topic = state.topic
    Trebek.Credo.subscribe(topic)

    snapshot =
      Trebek.Credo.get()
      |> Enum.filter(fn {{t, _}, _} -> t === topic end)
      |> Enum.map(fn {{_, k}, v} -> {k, v} end)

    partitioned =
      snapshot
      |> multisplit(fn {k, _} ->
        case k do
          {:votes, _} -> :votes
          {:responses, _} -> :responses
          :prompts -> :prompts
          _ -> nil
        end
      end)

    votes =
      partitioned
      |> Map.get(:votes, [])
      |> Enum.map(fn {{:votes, u}, vs} -> {u, vs} end)
      |> Map.new()

    responses =
      partitioned
      |> Map.get(:responses, [])
      |> Enum.map(fn {{:responses, u}, rs} -> {u, rs} end)
      |> Map.new()

    prompts =
      partitioned
      |> Map.get(:prompts, [%{active: nil, prompts: []}])
      |> hd()

    vote_count = votes |> Map.values() |> List.flatten() |> Enum.frequencies()

    responses_by_prompt =
      responses
      |> Enum.flat_map(fn {_, rs} -> rs end)
      |> Enum.chunk_by(fn r -> r.prompt end)
      |> Enum.map(fn rs -> {hd(rs).prompt, rs} end)
      |> Map.new()

    pub(state.room, :vote_count, vote_count)

    pub(
      state.room,
      :responses,
      {prompts.active, responses_by_prompt |> Map.get(prompts.active, [])}
    )

    pub(state.room, :prompts_state, prompts)

    {:noreply,
     state
     |> Map.put(:prompts_state, prompts)
     |> Map.put(:votes_state, %{votes: votes, vote_count: vote_count})
     |> Map.put(:responses_state, %{
       responses_by_user: responses,
       responses_by_prompt: responses_by_prompt
     })}
  end

  @impl true
  def handle_info(diffs = %Aviato.Diffs{}, state) do
    {adds, removes} =
      Aviato.Diffs.strip_topic(diffs)
      |> Aviato.Diffs.split()

    partition_fn = fn k ->
      case k do
        {:votes, _} -> :votes
        {:responses, _} -> :responses
        :prompts -> :prompts
        _ -> nil
      end
    end

    p_adds = adds |> multisplit(fn {k, _} -> partition_fn.(k) end)
    p_removes = removes |> multisplit(partition_fn)

    votes_adds = p_adds |> Map.get(:votes, [])
    votes_removes = p_removes |> Map.get(:votes, [])

    votes =
      state.votes_state.votes
      |> Map.merge(Map.new(votes_adds))
      |> Map.drop(votes_removes)

    # TODO(OPTIMIZE): I think this should work, feels premature to do that.
    # vote_count =
    #   state.votes_state.vote_count
    #   |> Counter.add(votes_adds |> Enum.map(fn {_, v} -> v end) |> List.flatten())
    #   |> Counter.subtract(
    #     state.votes_state.votes
    #     |> Map.take(votes_adds |> (Enum.map(fn {k, _} -> k end) ++ votes_removes))
    #     |> Map.values()
    #     |> List.flatten()
    #   )
    vote_count = votes |> Map.values() |> List.flatten() |> Enum.frequencies()

    responses_adds = p_adds |> Map.get(:responses, [])
    responses_removes = p_removes |> Map.get(:responses, [])

    responses =
      state.responses_state.responses_by_user
      |> Map.merge(Map.new(responses_adds))
      |> Map.drop(responses_removes)

    responses_by_prompt =
      responses
      |> Enum.flat_map(fn {_, rs} -> rs end)
      |> Enum.chunk_by(fn r -> r.prompt end)
      |> Enum.map(fn rs -> {hd(rs).prompt, rs} end)
      |> Map.new()

    {:prompts, prompts} = p_adds |> Map.get(:prompts, [{:prompts, state.prompts_state}]) |> hd()
    IO.inspect(["PROMPTS", prompts])
    # TODO: handle prompts_removes
    # prompts_removes = p_removes |> Map.get(:prompts, [])

    pub(state.room, :vote_count, vote_count)

    pub(
      state.room,
      :responses,
      {prompts.active, responses_by_prompt |> Map.get(prompts.active, [])}
    )

    pub(state.room, :prompts_state, prompts)

    {:noreply,
     %{
       state
       | prompts_state: prompts,
         votes_state: %{votes: votes, vote_count: vote_count},
         responses_state: %{
           responses_by_user: responses,
           responses_by_prompt: responses_by_prompt
         }
     }}
  end

  @impl true
  def handle_call({:snapshot, user}, _from, state) do
    {
      :reply,
      %{
        room: %{
          prompts_state: state.prompts_state,
          vote_count: state.votes_state.vote_count,
          responses:
            {state.prompts_state.active,
             state.responses_state.responses_by_prompt |> Map.get(state.prompts_state.active, [])}
        },
        me: %{
          votes: state.votes_state.votes |> Map.get(user, []),
          responses: state.responses_state.responses_by_user |> Map.get(user, [])
        }
      },
      state
    }
  end

  def pub(room, event, payload) do
    Phoenix.PubSub.broadcast(
      Trebek.PubSub,
      "#{__MODULE__}<#{room}>",
      %Trebek.RoomDaemon.Event{
        event: event,
        payload: payload
      }
    )
  end
end
