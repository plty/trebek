defmodule TrebekWeb.AuthController do
  use TrebekWeb, :controller
  import Plug.Conn
  alias Argon2

  def login_guest_page(conn, _params) do
    render(conn, :login)
  end

  def login_guest(conn, %{"user" => %{"username" => username}}) do
    id = Uniq.UUID.uuid7()

    Trebek.Credo.put({:credential, id}, %{
      username: username,
      password: nil
    })

    user = %{id: id, username: username}

    conn
    |> TrebekWeb.Guardian.Plug.sign_in(user, user)
    |> redirect(to: ~p"/room")
  end

  def index(conn, _params) do
    current_user = conn.assigns.current_user

    conn =
      case current_user do
        nil -> conn |> assign(:is_guest, true)
        user -> conn |> assign(:is_guest, is_guest?(user.id))
      end

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
    render(conn, :register)
  end

  def register(conn, %{"user" => %{"username" => username, "password" => password}}) do
    id = Uniq.UUID.uuid7()
    put_password_hash(id, username, password)
    user = %{id: id, username: username}

    conn
    |> TrebekWeb.Guardian.Plug.sign_in(user, user)
    |> redirect(to: ~p"/room")
  end

  def logout(conn, _params) do
    conn
    |> TrebekWeb.Guardian.Plug.sign_out()
    |> redirect(to: ~p"/room")
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

  def is_guest?(user_id) do
    case Trebek.Credo.get({:credential, user_id}) do
      %{username: username, password: hashed_password} -> hashed_password == nil
      nil -> {:error, :invalid_credentials}
    end
  end
end
