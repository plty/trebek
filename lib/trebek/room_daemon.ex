defmodule Trebek.RoomDaemon.Event do
  defstruct [:event, :payload]
end

defmodule Trebek.RoomDaemon do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def subscribe(room) do
    Phoenix.PubSub.subscribe(Trebek.PubSub, "#{__MODULE__}<#{room}>")
  end

  @impl true
  def init(opts) do
    %{room: room} = opts |> Enum.into(%{})
    IO.inspect(["0.0", opts, room])
    Trebek.Credo.subscribe("room<#{room}>")
    problem = Trebek.Credo.get({"room<#{room}>", :problem})
    {:ok, %{room: room, problem: problem}}
  end

  @impl true
  def handle_info(%Aviato.DeltaCrdt.Diffs{diffs: diffs}, state) do
    problem =
      diffs
      |> Enum.reduce(state[:problem], fn d, p ->
        case d do
          {:add, {_p, :problem}, v} -> v
          {:remove, {_p, :problem}} -> nil
          _ -> p
        end
      end)

    Phoenix.PubSub.broadcast(
      Trebek.PubSub,
      "#{__MODULE__}<#{state[:room]}>",
      %Trebek.RoomDaemon.Event{
        event: :problem_update,
        payload: %{problem: problem}
      }
    )

    {:noreply, %{state | problem: problem}}
  end
end
