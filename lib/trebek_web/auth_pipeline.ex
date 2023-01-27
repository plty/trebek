defmodule TrebekWeb.AuthPipeline.ErrorHandler do
  import Phoenix.Controller

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {_type, _reason}, _opts) do
    conn |> redirect(to: "/auth")
  end
end

defmodule TrebekWeb.AuthPipeline do
  use Guardian.Plug.Pipeline,
    error_handler: TrebekWeb.AuthPipeline.ErrorHandler,
    otp_app: :trebek,
    module: TrebekWeb.Guardian

  import Plug.Conn

  plug Guardian.Plug.VerifySession, claims: %{"typ" => "access"}
  plug Guardian.Plug.VerifyHeader, claims: %{"typ" => "access"}
  plug Guardian.Plug.LoadResource, allow_blank: true
  plug :fetch_current_user

  def fetch_current_user(conn, _opts) do
    conn |> assign(:current_user, TrebekWeb.Guardian.Plug.current_resource(conn))
  end
end
