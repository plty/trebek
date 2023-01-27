defmodule Trebek.Credo do
  use Aviato.DeltaCrdt

  def put(k, v) do
    DeltaCrdt.put(__MODULE__, k, v)
  end

  def get() do
    DeltaCrdt.to_map(__MODULE__)
  end

  def get(k) do
    DeltaCrdt.get(__MODULE__, k)
  end

  def subscribe(topic) do
    IO.inspect(["OwO", "#{__MODULE__}::#{topic}"])
    Phoenix.PubSub.subscribe(Trebek.PubSub, "#{__MODULE__}::#{topic}")
  end
end
