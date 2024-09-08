defmodule MagusLive.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MagusLiveWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:magus_live, :dns_cluster_query) || :ignore},
      Supervisor.child_spec({Phoenix.PubSub, name: MagusLive.PubSub}, id: :pubsub_magislive),
      Supervisor.child_spec({Phoenix.PubSub, name: Magus.PubSub}, id: :pubsub_magis),
      # Start the Finch HTTP client for sending emails
      {Finch, name: MagusLive.Finch},
      # Start a worker by calling: MagusLive.Worker.start_link(arg)
      # {MagusLive.Worker, arg},
      # Start to serve requests, typically the last entry
      MagusLiveWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MagusLive.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MagusLiveWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
