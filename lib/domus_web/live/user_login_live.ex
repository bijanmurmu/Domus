defmodule DomusWeb.UserLoginLive do
  use DomusWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="home-container">
      <div class="bento-card">
        <h1 style="margin-bottom: 10px;">Sign In</h1>
        <p style="font-family: 'Lato', sans-serif; font-size: 0.95rem; color: var(--text-muted); margin-bottom: 30px;">
          Identify yourself to access the ledger.
        </p>
        
        <form action={~p"/users/log_in"} method="post">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <input type="email" name="user[email]" value={@form[:email].value} placeholder="Email address" required autocomplete="email" style="margin-bottom: 15px;" />
          <input type="password" name="user[password]" placeholder="Password" required autocomplete="current-password" style="margin-bottom: 15px;" />
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
            <label style="font-family: 'Lato', sans-serif; font-size: 0.9rem; color: var(--text-main); display: flex; align-items: center; gap: 5px;">
              <input type="checkbox" name="user[remember_me]" value="true" style="width: auto; margin: 0;" />
              Keep me logged in
            </label>
          </div>
          <button type="submit">Log In</button>
        </form>
        
        <div style="margin-top: 30px; text-align: center; border-top: 1px solid var(--line-color); padding-top: 20px;">
          <p style="font-family: 'Lato', sans-serif; font-size: 0.9rem; color: var(--text-muted);">
            Don't have an account? 
            <.link navigate={~p"/users/register"} style="color: var(--text-main); font-weight: bold; text-decoration: none;">Register here</.link>.
          </p>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
