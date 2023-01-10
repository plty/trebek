defmodule Trebek.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = [
      mesh_gossip: [
        strategy: Cluster.Strategy.Gossip,
        # TODO[low](jer): do multicast rather than broadcast :/ or not.
        config: [
          multicast_addr: "255.255.255.255",
          broadcast_only: true,
          secret: "shoosh"
        ]
      ]
    ]

    children = [
      # Start the Cluster supervisor
      {Cluster.Supervisor, [topologies, [name: Trebek.ClusterSupervisor]]},
      # Start the NodeObserver system
      {Trebek.NodeObserver, []},
      # Start the Telemetry supervisor
      TrebekWeb.Telemetry,
      # Start the Ecto repository
      # NOTE(jer): deactivated for debugging reasons
      # Trebek.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Trebek.PubSub},
      # Start Finch
      {Finch, name: Trebek.Finch},
      # Start the Endpoint (http/https)
      Trebek.Credo,
      TrebekWeb.Presence,
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
