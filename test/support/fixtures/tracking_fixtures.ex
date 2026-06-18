defmodule Domus.TrackingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Domus.Tracking` context.
  """

  @doc """
  Generate a log.
  """
  def log_fixture(attrs \\ %{}) do
    {:ok, log} =
      attrs
      |> Enum.into(%{
        chore: "some chore",
        roommate_name: "some roommate_name"
      })
      |> Domus.Tracking.create_log()

    log
  end
end
