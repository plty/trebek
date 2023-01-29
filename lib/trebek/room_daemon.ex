defmodule Trebek.RoomDaemon.Event do
  defstruct [:event, :payload]
end

defmodule Trebek.RoomDaemon do
  use GenServer

  def start_link(opts) do
    opts = opts |> Enum.into(%{})

    case GenServer.start_link(__MODULE__, opts, name: via_tuple(opts[:room])) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, _pid}} ->
        :ignore
    end
  end

  def subscribe(room) do
    Phoenix.PubSub.subscribe(Trebek.PubSub, "#{__MODULE__}<#{room}>")
  end

  def via_tuple(room), do: {:via, Horde.Registry, {Trebek.Registry, "#{__MODULE__}<#{room}>"}}

  @impl true
  def init(opts) do
    %{room: room} = opts |> Enum.into(%{})
    IO.inspect(["0.0", opts, room])
    Trebek.Credo.subscribe("room<#{room}>")
    problem = Trebek.Credo.get({"room<#{room}>", :problem})
    {:ok, %{room: room, problem: problem}}
  end

  def update_freqs(prev_freqs, diffs) do
    adds =
      diffs
      |> Enum.flat_map(fn d ->
        case d do
          {:add, {_, {:vote, q, _}}, _} -> [q]
          _ -> []
        end
      end)
      |> Enum.frequencies()

    removes =
      diffs
      |> Enum.flat_map(fn d ->
        case d do
          {:remove, {_, {:vote, q, _}}} -> [q]
          _ -> []
        end
      end)
      |> Enum.frequencies()
      |> Map.new(fn {k, f} -> {k, -f} end)

    prev_freqs
    |> Map.merge(adds, fn _, u, v -> u + v end)
    |> Map.merge(removes, fn _, u, v -> u + v end)
  end

  @impl true
  def handle_info(%Aviato.Diffs{diffs: diffs}, state) do
    problem =
      diffs
      |> Enum.reduce(state[:problem], fn d, p ->
        case d do
          {:add, {_p, :problem}, v} -> v
          {:remove, {_p, :problem}} -> nil
          _ -> p
        end
      end)

    pub(:prompt_update, state[:room], problem)

    {:noreply, %{state | problem: problem}}
  end

  def pub(:prompt_update, room, problem) do
    Phoenix.PubSub.broadcast(
      Trebek.PubSub,
      "#{__MODULE__}<#{room}>",
      %Trebek.RoomDaemon.Event{
        event: :prompt_update,
        payload: %{problem: problem}
      }
    )
  end
end
