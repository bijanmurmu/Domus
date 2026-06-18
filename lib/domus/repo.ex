defmodule Domus.Repo do
  use Ecto.Repo,
    otp_app: :domus,
    adapter: Ecto.Adapters.Postgres
end
