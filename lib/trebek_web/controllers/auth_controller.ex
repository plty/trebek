defmodule TrebekWeb.AuthController do
  use TrebekWeb, :controller
  import Plug.Conn

  def index(conn, _params) do
    render(conn, :index)
  end

  def login(conn, %{"user" => %{"username" => username, "password" => _password}}) do
    id = Uniq.UUID.uuid7()
    user = %{id: id, username: username}

    conn
    |> TrebekWeb.Guardian.Plug.sign_in(user, user)
    |> redirect(to: ~p"/")
  end

  def logout(conn, _params) do
    conn
    |> TrebekWeb.Guardian.Plug.sign_out()
    |> redirect(to: ~p"/auth")
  end
end
