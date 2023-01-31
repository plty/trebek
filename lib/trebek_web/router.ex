defmodule TrebekWeb.Router do
  use TrebekWeb, :router

  pipeline :ensure_auth do
    plug Guardian.Plug.EnsureAuthenticated
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {TrebekWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    plug TrebekWeb.AuthPipeline
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TrebekWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", TrebekWeb do
    pipe_through [:browser, :ensure_auth]

    live_session :default, on_mount: [TrebekWeb.AuthLive, TrebekWeb.EnsureAuthLive] do
      live "/mcqs", MCQLive.Index, :index
      live "/room", RoomLive.Index, :index
      live "/room/:id", RoomLive.Show, :index
      live "/room/:id/manage", RoomLive.Edit, :index
    end
  end

  scope "/auth", TrebekWeb do
    pipe_through [:browser]

    get "/", AuthController, :index
    post "/login", AuthController, :login
    get "/logout", AuthController, :logout
    get "/register", AuthController, :register_page
    post "/register", AuthController, :register
  end

  # Other scopes may use custom stacks.
  scope "/api", TrebekWeb do
    pipe_through :api

    get "/peers", APIController, :peers
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:trebek, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard",
        metrics: TrebekWeb.Telemetry,
        metrics_history: {TrebekWeb.MetricsStorage, :metrics_history, []}

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
