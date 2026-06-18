defmodule Domus.Tracking.Log do
  use Ecto.Schema
  import Ecto.Changeset

  schema "logs" do
    field :room_code, :string
    field :roommate_name, :string
    field :chore, :string
    field :approved_by, :string

    timestamps()
  end

  @doc false
  def changeset(log, attrs) do
    log
    |> cast(attrs, [:room_code, :roommate_name, :chore, :approved_by, :inserted_at])
    |> validate_required([:room_code, :roommate_name, :chore])
  end
end
