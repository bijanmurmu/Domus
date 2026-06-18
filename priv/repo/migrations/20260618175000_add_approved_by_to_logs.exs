defmodule Domus.Repo.Migrations.AddApprovedByToLogs do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      add :approved_by, :string
    end
  end
end
