# HACK: this is incorrect but good enough
defimpl Jason.Encoder, for: Tuple do
  def encode(data, options) when is_tuple(data) do
    data
    |> Tuple.to_list()
    |> Jason.Encoder.List.encode(options)
  end
end

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

  def get_topic(topic) do
    get()
    |> Enum.filter(fn {{t, _}, _} -> t == topic end)
    |> Map.new()
  end

  def subscribe(topic) do
    Phoenix.PubSub.subscribe(Trebek.PubSub, "#{__MODULE__}::#{topic}")
  end
end
