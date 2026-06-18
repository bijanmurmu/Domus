defmodule DomusWeb.UserSettingsLive do
  use DomusWeb, :live_view

  alias Domus.Accounts

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok -> put_flash(socket, :info, "Email changed successfully.")
        :error -> put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)
    name_changeset = Accounts.change_user_name(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:name_form, to_form(name_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_name", %{"user" => user_params}, socket) do
    name_form =
      socket.assigns.current_user
      |> Accounts.change_user_name(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, name_form: name_form)}
  end

  def handle_event("update_name", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user

    case Accounts.update_user_name(user, user_params) do
      {:ok, _applied_user} ->
        {:noreply, socket |> put_flash(:info, "Name updated successfully.") |> push_navigate(to: ~p"/users/settings")}

      {:error, changeset} ->
        {:noreply, assign(socket, :name_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="home-container">
      <div class="bento-card" style="max-width: 600px; margin: 0 auto; width: 100%;">
        <h1 style="font-size: 3rem; margin-bottom: 10px; border-bottom: none; padding-bottom: 0;">Resident Profile</h1>
        <p style="margin-bottom: 40px; font-size: 1.1rem; border-bottom: 2px solid var(--line-color); padding-bottom: 20px;">Manage your identity.</p>
        
        <div class="editorial-section">
          <h3 style="font-size: 1.5rem; margin-bottom: 20px;">Identity</h3>
          <.simple_form for={@name_form} id="name_form" phx-submit="update_name" phx-change="validate_name">
            <div style="margin-bottom: 20px;">
              <.input field={@name_form[:name]} type="text" placeholder="Resident Name" required />
            </div>
            <button type="submit" style="background: transparent; color: var(--text-main); border: 1px solid var(--text-main); margin-top: 10px;">Update Name</button>
          </.simple_form>
        </div>

        <div class="editorial-section">
          <h3 style="font-size: 1.5rem; margin-bottom: 20px;">Email Address</h3>
          <.simple_form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
            <div style="margin-bottom: 20px;">
              <.input field={@email_form[:email]} type="email" placeholder="New Email" required />
            </div>
            <div style="margin-bottom: 20px;">
              <.input field={@email_form[:current_password]} name="current_password" type="password" placeholder="Current Password" value={@email_form_current_password} required />
            </div>
            <button type="submit" style="background: transparent; color: var(--text-main); border: 1px solid var(--text-main); margin-top: 10px;">Change Email</button>
          </.simple_form>
        </div>

        <div class="editorial-section" style="border-bottom: none; margin-bottom: 0;">
          <h3 style="font-size: 1.5rem; margin-bottom: 20px;">Security</h3>
          <.simple_form for={@password_form} id="password_form" action={~p"/users/log_in?_action=password_updated"} method="post" phx-change="validate_password" phx-submit="update_password" phx-trigger-action={@trigger_submit}>
            <input name={@password_form[:email].name} type="hidden" value={@current_email} />
            <div style="margin-bottom: 20px;">
              <.input field={@password_form[:password]} type="password" placeholder="New Password" required />
            </div>
            <div style="margin-bottom: 20px;">
              <.input field={@password_form[:password_confirmation]} type="password" placeholder="Confirm Password" required />
            </div>
            <div style="margin-bottom: 20px;">
              <.input field={@password_form[:current_password]} name="current_password" type="password" placeholder="Current Password" value={@current_password} required />
            </div>
            <button type="submit" style="background: var(--text-main); color: var(--bg-color); border: 1px solid var(--text-main); margin-top: 10px;">Update Password</button>
          </.simple_form>
        </div>

        <div style="margin-top: 40px; text-align: center; padding-top: 20px; border-top: 1px solid var(--line-color);">
          <.link navigate={~p"/"} style="font-family: 'Playfair Display', serif; font-style: italic; color: var(--text-muted); text-decoration: underline; font-size: 1.2rem;">&larr; Return to Dashboard</.link>
        </div>
      </div>
    </div>
    """
  end
end
