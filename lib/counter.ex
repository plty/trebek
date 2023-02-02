defmodule Counter do
  def new(m) when is_map(m) do
    m
  end

  def new(l) when is_list(l) do
    l |> Enum.frequencies()
  end

  def add(a, b) do
    Map.merge(
      Counter.new(a),
      Counter.new(b),
      fn _, x, y -> x + y end
    )
  end

  def subtract(a, b) do
    Map.merge(
      Counter.new(a),
      Counter.new(b)
      |> Enum.map(fn {k, f} -> {k, -f} end)
      |> Map.new(),
      fn _, x, y -> x + y end
    )
  end
end
