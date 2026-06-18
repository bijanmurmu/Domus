defmodule DomusWeb.UserRegistrationLive do
  use DomusWeb, :live_view

  alias Domus.Accounts
  alias Domus.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="home-container">
      <div class="bento-card">
        <h1 style="margin-bottom: 10px;">Register</h1>
        <p style="font-family: 'Lato', sans-serif; font-size: 0.95rem; color: var(--text-muted); margin-bottom: 30px;">
          Create your digital identity for the ledger.
        </p>
        
        <.form
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
          phx-trigger-action={@trigger_submit}
          action={~p"/users/log_in?_action=registered"}
          method="post"
        >
          <%= if @check_errors do %>
            <div style="color: #cc0000; font-family: 'Lato', sans-serif; font-size: 0.9rem; margin-bottom: 15px;">
              Oops, something went wrong! Please check the errors below.
            </div>
          <% end %>

          <div style="margin-bottom: 15px;">
            <input type="text" name={@form[:name].name} value={@form[:name].value} placeholder="Full Name" required autocomplete="name" />
            <%= for {msg, _} <- @form[:name].errors do %>
              <div style="color: #cc0000; font-size: 0.8rem; margin-top: 5px;"><%= msg %></div>
            <% end %>
          </div>
          <div style="margin-bottom: 15px;">
            <input type="email" name={@form[:email].name} value={@form[:email].value} placeholder="Email address" required autocomplete="email" />
            <%= for {msg, _} <- @form[:email].errors do %>
              <div style="color: #cc0000; font-size: 0.8rem; margin-top: 5px;"><%= msg %></div>
            <% end %>
          </div>
          <div style="margin-bottom: 15px;">
            <input type="password" name={@form[:password].name} value={@form[:password].value} placeholder="Password" required autocomplete="new-password" />
            <%= for {msg, _} <- @form[:password].errors do %>
              <div style="color: #cc0000; font-size: 0.8rem; margin-top: 5px;"><%= msg %></div>
            <% end %>
          </div>

          <button type="submit">Create Account</button>
        </.form>
        
        <div style="margin-top: 30px; text-align: center; border-top: 1px solid var(--line-color); padding-top: 20px;">
          <p style="font-family: 'Lato', sans-serif; font-size: 0.9rem; color: var(--text-muted);">
            Already have an account? 
            <.link navigate={~p"/users/log_in"} style="color: var(--text-main); font-weight: bold; text-decoration: none;">Sign in</.link>.
          </p>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
