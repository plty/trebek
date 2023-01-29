defmodule TrebekWeb.AuthController do
  use TrebekWeb, :controller
  import Plug.Conn
  alias Argon2

  def index(conn, _params) do
    render(conn, :index)
  end

  def login(conn, %{"user" => %{"user_id" => id, "password" => password}}) do
    case authenticate_user(id, nil, password) do
      {:ok, %{id: user_id, username: username}} ->
        user = %{id: user_id, username: username}

        conn
        |> TrebekWeb.Guardian.Plug.sign_in(user, user)
        |> redirect(to: ~p"/auth")

      {:error, reason} ->
        conn
        |> put_flash(:error, to_string(reason))
        |> redirect(to: ~p"/auth")
    end
  end

  def register_page(conn, _params) do
    if conn.assigns.current_user do
      conn
      |> redirect(to: ~p"/auth")
    end

    render(conn, :register)
  end

  def register(conn, %{"user" => %{"username" => username, "password" => password}}) do
    id = Uniq.UUID.uuid7()
    put_password_hash(id, username, password)
    user = %{id: id, username: username}

    conn
    |> TrebekWeb.Guardian.Plug.sign_in(user, user)
    |> redirect(to: ~p"/auth")
  end

  def logout(conn, _params) do
    conn
    |> TrebekWeb.Guardian.Plug.sign_out()
    |> redirect(to: ~p"/auth")
  end

  defp put_password_hash(user_id, username, password) do
    Trebek.Credo.put({:credential, user_id}, %{
      username: username,
      password: Argon2.hash_pwd_salt(password)
    })
  end

  defp authenticate_user(user_id, _username, password) do
    case Trebek.Credo.get({:credential, user_id}) do
      %{username: username, password: hashed_password} ->
        if Argon2.verify_pass(password, hashed_password) do
          {:ok, %{id: user_id, username: username}}
        else
          {:error, :invalid_credentials}
        end

      nil ->
        Argon2.no_user_verify()
        {:error, :invalid_credentials}
    end
  end
end
