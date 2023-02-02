# adapted from https://jumpwire.ai/blog/in-memory-distributed-state-with-delta-crdts

defmodule Aviato.Diffs do
  defstruct [:module, :topic, :diffs]

  def strip_topic(%Aviato.Diffs{diffs: diffs}) do
    %Aviato.Diffs{
      diffs:
        diffs
        |> Enum.map(fn d ->
          case d do
            {:add, {_t, k}, v} -> {:add, k, v}
            {:remove, {_t, k}} -> {:remove, k}
          end
        end)
    }
  end

  def split(%Aviato.Diffs{diffs: diffs}) do
    {adds, removes} =
      diffs
      |> Enum.split_with(fn d ->
        case d do
          {:add, _, _} -> true
          {:remove, _} -> false
        end
      end)

    {adds |> Enum.map(fn {:add, k, v} -> {k, v} end),
     removes |> Enum.map(fn {:remove, k} -> k end)}
  end
end

defmodule Aviato.DeltaCrdt do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      opts =
        opts
        |> Keyword.put_new(:monitor_name, :"#{__MODULE__}.Monitor")
        |> Keyword.put_new(:crdt_name, __MODULE__)

      defmodule CrdtSupervisor do
        use Supervisor

        @monitor_name opts[:monitor_name]
        @crdt_name opts[:crdt_name]

        def start_link(init_opts) do
          Supervisor.start_link(__MODULE__, init_opts, name: __MODULE__)
        end

        @impl true
        def init(init_opts) do
          crdt_opts =
            [
              crdt: DeltaCrdt.AWLWWMap,
              on_diffs: &on_diffs/1,
              name: @crdt_name
            ]
            |> Keyword.merge(init_opts)

          children = [
            {DeltaCrdt, crdt_opts},
            {Aviato.DeltaCrdt, [crdt: @crdt_name, name: @monitor_name]},
            {Horde.NodeListener, @monitor_name}
          ]

          Supervisor.init(children, strategy: :one_for_one)
        end

        def topic_of(diff) do
          case diff do
            {:add, {p, _k}, _v} ->
              p

            {:remove, {p, _k}} ->
              p
          end
        end

        def on_diffs(diffs) do
          IO.inspect([".-.", diffs])

          diffs
          |> Enum.sort_by(&topic_of/1)
          |> Enum.chunk_by(&topic_of/1)
          |> Enum.each(fn diffs ->
            IO.inspect(["UwU", "#{@crdt_name}::#{topic_of(hd(diffs))}"])

            topic = topic_of(hd(diffs))

            Phoenix.PubSub.local_broadcast(
              Trebek.PubSub,
              "#{@crdt_name}::#{topic}",
              %Aviato.Diffs{
                module: @crdt_name,
                topic: topic,
                diffs: diffs
              }
            )
          end)
        end
      end

      def child_spec(opts) do
        CrdtSupervisor.child_spec(opts)
      end
    end
  end

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl true
  def init(opts) do
    members = Horde.NodeListener.make_members(opts[:name])

    state =
      opts
      |> Enum.into(%{})
      |> Map.put(:members, members)

    self = Node.self()

    neighbors =
      members
      |> Enum.filter(fn member -> member != {opts[:name], self} end)
      |> Enum.map(fn {_, node} -> {opts[:crdt], node} end)

    DeltaCrdt.set_neighbours(opts[:crdt], neighbors)

    {:ok, state}
  end

  @impl true
  def handle_call({:set_members, members}, _from, state = %{crdt: crdt, name: name}) do
    neighbors =
      members
      |> Stream.filter(fn member -> member != {name, Node.self()} end)
      |> Enum.map(fn {_, node} -> {crdt, node} end)

    DeltaCrdt.set_neighbours(crdt, neighbors)

    {:reply, :ok, %{state | members: members}}
  end

  @impl true
  def handle_call(:members, _from, state = %{members: members}) do
    {:reply, MapSet.to_list(members), state}
  end
end
