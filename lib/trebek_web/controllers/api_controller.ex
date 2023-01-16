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
end
