defmodule Trebek.Problem.MultipleChoice do
  defstruct [:q, :c]
end

defmodule Trebek.Problem.ShortAnswer do
  defstruct [:q]
end

defmodule TrebekWeb.RoomLive.Edit do
  use TrebekWeb, :live_view

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    Trebek.Credo.put("problem:" <> room_id, "Siapa nama bokapnya otto?")

    {:ok,
     socket
     |> assign(:type, :mcq)
     |> assign(:changeset, %{})}
  end
end
