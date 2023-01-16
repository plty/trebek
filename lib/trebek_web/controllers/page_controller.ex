defmodule TrebekWeb.PageController do
  use TrebekWeb, :controller
  # import Plug.Conn

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def peers(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn |> assign(:peers, ["1324"]), :peers, layout: false)
  end
end
