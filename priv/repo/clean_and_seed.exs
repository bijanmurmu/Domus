alias Domus.Repo
alias Domus.Tracking.Log
import Ecto.Query

Repo.delete_all(Log)

room_code = "flat-4b"
roommates = ["Bijan", "Alex", "Sam"]
chores = ["Water Plants", "Sweep Floors", "Mop Floors", "Clean Bathroom"]

for _ <- 1..25 do
  date = DateTime.add(DateTime.utc_now(), -:rand.uniform(86400 * 5), :second) |> DateTime.truncate(:second)
  Repo.insert!(%Log{
    room_code: room_code,
    roommate_name: Enum.random(roommates),
    chore: Enum.random(chores),
    inserted_at: date,
    updated_at: date
  })
end
