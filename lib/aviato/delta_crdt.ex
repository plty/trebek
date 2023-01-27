# copied from https://jumpwire.ai/blog/in-memory-distributed-state-with-delta-crdts
defmodule Aviato.DeltaCrdt do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      cluster = opts[:cluster]

      opts =
        opts
        |> Keyword.put_new(:cluster_name, :"#{__MODULE__}.Monitor")
        |> Keyword.put_new(:crdt_mod, __MODULE__)
        |> Keyword.put_new(:crdt_opts, [])

      @crdt opts[:crdt_mod]

      defmodule CrdtSupervisor do
        use Supervisor

        @cluster_name opts[:cluster_name]
        @crdt opts[:crdt_mod]
        @crdt_opts opts[:crdt_opts]

        def start_link(init_opts) do
          Supervisor.start_link(__MODULE__, init_opts, name: __MODULE__)
        end

        @impl true
        def init(init_opts) do
          crdt_opts =
            [
              crdt: DeltaCrdt.AWLWWMap,
              on_diffs: fn diff -> IO.inspect(["diff", Node.self(), diff]) end,
              name: @crdt
            ]
            |> Keyword.merge(@crdt_opts)
            |> Keyword.merge(init_opts)

          IO.inspect(["crdt_opts", crdt_opts])
          IO.inspect(["cluster_name", @cluster_name])

          children = [
            {DeltaCrdt, crdt_opts},
            {Aviato.DeltaCrdt, [crdt: @crdt, name: @cluster_name]},
            {Horde.NodeListener, @cluster_name}
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
    IO.inspect(["SET MEMBERS", members])

    neighbors =
      members
      |> Stream.filter(fn member -> member != {name, Node.self()} end)
      |> Enum.map(fn {_, node} -> {crdt, node} end)

    DeltaCrdt.set_neighbours(crdt, neighbors)

    {:reply, :ok, %{state | members: members}}
  end

  @impl true
  def handle_call(:members, _from, state = %{members: members}) do
    IO.inspect(["WHO MEMBERS", members])
    {:reply, MapSet.to_list(members), state}
  end
end
