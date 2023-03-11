defmodule TrebekWeb.APIController do
  use TrebekWeb, :controller

  def peers(conn, _params) do
    json(conn, %{
      status: :ok,
      data: %{
        self: %{
          name: Node.self(),
          alive: Node.alive?()
        },
        peers: Node.list(:visible)
      }
    })
  end

  def export_response(conn, %{"room_id" => room_id}) do
    data =
      Trebek.Credo.get_topic("room<#{room_id}>")
      |> Enum.map(fn {{_topic, k}, v} ->
        case k do
          :owner -> {:owner, %{id: v.id, username: v.username}}
          {:responses, resp_id} -> {"response<#{resp_id}>", v}
          k -> {k, v}
        end
      end)
      |> Map.new()

    json(conn, data)
  end
end
