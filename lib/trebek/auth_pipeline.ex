defmodule Trebek.AuthPipeline.ErrorHandler do
  import Plug.Conn

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    body = to_string(type)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(401, body)
  end
end

defmodule Trebek.AuthPipeline do
  use Guardian.Plug.Pipeline,
    error_handler: Trebek.AuthPipeline.ErrorHandler,
    otp_app: :trebek,
    module: Trebek.Guardian

  import Plug.Conn

  plug Guardian.Plug.VerifySession, claims: %{"typ" => "access"}
  plug Guardian.Plug.VerifyHeader, claims: %{"typ" => "access"}
  plug Guardian.Plug.LoadResource, allow_blank: true
  plug :fetch_current_user

  def fetch_current_user(conn, _opts) do
    IO.inspect(["CURRENT USER", Trebek.Guardian.Plug.current_resource(conn)])
    conn |> assign(:current_user, Trebek.Guardian.Plug.current_resource(conn))
  end
end
