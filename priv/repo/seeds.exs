alias Domus.Repo
alias Domus.Tracking.Log

room_code = "flat-4b"
roommates = ["Bijan", "Alex", "Sam"]
chores = ["💧 Water", "🧹 Swept", "🧽 Mopped", "🚽 Toilet"]

for _ <- 1..40 do
  date = DateTime.add(DateTime.utc_now(), -:rand.uniform(86400 * 7), :second) |> DateTime.truncate(:second)
  Repo.insert!(%Log{
    room_code: room_code,
    roommate_name: Enum.random(roommates),
    chore: Enum.random(chores),
    inserted_at: date,
    updated_at: date
  })
end
