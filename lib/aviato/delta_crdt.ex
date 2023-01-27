# copied from https://jumpwire.ai/blog/in-memory-distributed-state-with-delta-crdts
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
              on_diffs: fn diff -> IO.inspect(["diff", Node.self(), diff]) end,
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
