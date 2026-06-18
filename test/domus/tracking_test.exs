defmodule Domus.TrackingTest do
  use Domus.DataCase

  alias Domus.Tracking

  describe "logs" do
    alias Domus.Tracking.Log

    import Domus.TrackingFixtures

    @invalid_attrs %{chore: nil, roommate_name: nil}

    test "list_logs/0 returns all logs" do
      log = log_fixture()
      assert Tracking.list_logs() == [log]
    end

    test "get_log!/1 returns the log with given id" do
      log = log_fixture()
      assert Tracking.get_log!(log.id) == log
    end

    test "create_log/1 with valid data creates a log" do
      valid_attrs = %{chore: "some chore", roommate_name: "some roommate_name"}

      assert {:ok, %Log{} = log} = Tracking.create_log(valid_attrs)
      assert log.chore == "some chore"
      assert log.roommate_name == "some roommate_name"
    end

    test "create_log/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Tracking.create_log(@invalid_attrs)
    end

    test "update_log/2 with valid data updates the log" do
      log = log_fixture()
      update_attrs = %{chore: "some updated chore", roommate_name: "some updated roommate_name"}

      assert {:ok, %Log{} = log} = Tracking.update_log(log, update_attrs)
      assert log.chore == "some updated chore"
      assert log.roommate_name == "some updated roommate_name"
    end

    test "update_log/2 with invalid data returns error changeset" do
      log = log_fixture()
      assert {:error, %Ecto.Changeset{}} = Tracking.update_log(log, @invalid_attrs)
      assert log == Tracking.get_log!(log.id)
    end

    test "delete_log/1 deletes the log" do
      log = log_fixture()
      assert {:ok, %Log{}} = Tracking.delete_log(log)
      assert_raise Ecto.NoResultsError, fn -> Tracking.get_log!(log.id) end
    end

    test "change_log/1 returns a log changeset" do
      log = log_fixture()
      assert %Ecto.Changeset{} = Tracking.change_log(log)
    end
  end
end
