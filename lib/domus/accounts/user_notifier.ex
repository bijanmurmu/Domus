defmodule Domus.Accounts.UserNotifier do
  require Logger

  defp deliver(recipient, subject, body) do
    Logger.info("""
    MOCK EMAIL DELIVERED
    To: #{recipient}
    Subject: #{subject}
    Body:
    #{body}
    """)
    {:ok, %{}}
  end

  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", url)
  end

  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset password instructions", url)
  end

  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", url)
  end
end
