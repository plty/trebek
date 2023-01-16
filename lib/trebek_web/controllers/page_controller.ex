defmodule TrebekWeb.PageController do
  use TrebekWeb, :controller
  # import Plug.Conn

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end
end
