defmodule Domus.Tracking.RoomMember do
  use Ecto.Schema
  import Ecto.Changeset

  schema "room_members" do
    belongs_to :user, Domus.Accounts.User
    belongs_to :room, Domus.Tracking.Room
    field :is_super_user, :boolean, default: false

    timestamps()
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:user_id, :room_id, :is_super_user])
    |> validate_required([:user_id, :room_id, :is_super_user])
    |> unique_constraint([:user_id, :room_id])
  end
end
