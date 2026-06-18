defmodule Domus.Tracking.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field :code, :string
    field :name, :string
    belongs_to :creator, Domus.Accounts.User

    timestamps()
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:code, :name, :creator_id])
    |> validate_required([:code, :name, :creator_id])
    |> unique_constraint(:code)
  end
end
