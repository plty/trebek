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
      {Cluster.Supervisor, [topologies, [name: Trebek.ClusterSupervisor]]},
      TrebekWeb.Telemetry,
      # Trebek.Repo, # NOTE(jer): deactivated for debugging reasons
      {Phoenix.PubSub, name: Trebek.PubSub},
      {Finch, name: Trebek.Finch},
      Trebek.Credo,
      TrebekWeb.Presence,
      TrebekWeb.Endpoint
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
