defmodule Trebek.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      TrebekWeb.Telemetry,
      # Start the Ecto repository
      Trebek.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Trebek.PubSub},
      # Start Finch
      {Finch, name: Trebek.Finch},
      # Start the Endpoint (http/https)
      TrebekWeb.Endpoint
      # Start a worker by calling: Trebek.Worker.start_link(arg)
      # {Trebek.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Trebek.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TrebekWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
