defmodule Domus.Repo.Migrations.CreateLogs do
  use Ecto.Migration

  def change do
    create table(:logs) do
      add :room_code, :string, null: false
      add :roommate_name, :string
      add :chore, :string

      timestamps(type: :utc_datetime)
    end
    create index(:logs, [:room_code])
  end
end
