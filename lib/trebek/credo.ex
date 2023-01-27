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

  def handle_call({:set_members, members}, from, state) do
    IO.inspect("bebonghong?")
    Aviato.DeltaCrdt.handle_call({:set_members, members}, from, state)
  end

  def handle_call(:members, from, state) do
    IO.inspect("satjingkasler?")
    Aviato.DeltaCrdt.handle_call(:members, from, state)
  end
end
