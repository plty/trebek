defmodule Trebek.Repo do
  use Ecto.Repo,
    otp_app: :trebek,
    adapter: Ecto.Adapters.Postgres
end
