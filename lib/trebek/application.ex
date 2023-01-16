defmodule Trebek.Application do
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
      TrebekWeb.Telemetry,
      {TrebekWeb.MetricsStorage, TrebekWeb.Telemetry.metrics()},
      {Cluster.Supervisor, [topologies, [name: Trebek.ClusterSupervisor]]},
      {Phoenix.PubSub, name: Trebek.PubSub},
      {Finch, name: Trebek.Finch},
      {Horde.Registry, [name: Trebek.Registry, keys: :unique]},
      {Horde.DynamicSupervisor, [name: Trebek.DynamicSupervisor, strategy: :one_for_one]},
      Trebek.Credo,
      TrebekWeb.Presence,
      TrebekWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Trebek.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    TrebekWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
