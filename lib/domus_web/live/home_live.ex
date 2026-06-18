defmodule DomusWeb.HomeLive do
  use DomusWeb, :live_view
  import Ecto.Query

  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]
    my_rooms = 
      if user do
        Domus.Repo.all(
          from rm in Domus.Tracking.RoomMember,
          where: rm.user_id == ^user.id,
          join: r in Domus.Tracking.Room, on: rm.room_id == r.id,
          select: {r.name, r.code, rm.is_super_user}
        )
      else
        []
      end

    {:ok, assign(socket, my_rooms: my_rooms)}
  end

  def handle_event("join_room", %{"room_code" => room_code}, socket) do
    normalized_code = room_code |> String.trim() |> String.upcase()
    user = socket.assigns.current_user
    
    case Domus.Repo.get_by(Domus.Tracking.Room, code: normalized_code) do
      nil ->
        {:noreply, socket |> put_flash(:error, "Invalid invite code. Room not found.")}
      room ->
        member = Domus.Repo.get_by(Domus.Tracking.RoomMember, user_id: user.id, room_id: room.id)
        if is_nil(member) do
          %Domus.Tracking.RoomMember{}
          |> Domus.Tracking.RoomMember.changeset(%{user_id: user.id, room_id: room.id, is_super_user: false})
          |> Domus.Repo.insert!()
        end
        {:noreply, push_navigate(socket, to: ~p"/room/#{normalized_code}")}
    end
  end

  def handle_event("create_room", %{"name" => name}, socket) do
    user = socket.assigns.current_user
    code = generate_code()
    
    {:ok, room} = %Domus.Tracking.Room{}
    |> Domus.Tracking.Room.changeset(%{name: name, code: code, creator_id: user.id})
    |> Domus.Repo.insert()

    %Domus.Tracking.RoomMember{}
    |> Domus.Tracking.RoomMember.changeset(%{user_id: user.id, room_id: room.id, is_super_user: true})
    |> Domus.Repo.insert!()
    
    {:noreply, push_navigate(socket, to: ~p"/room/#{code}")}
  end

  defp generate_code() do
    :crypto.strong_rand_bytes(4) |> Base.encode16() |> binary_part(0, 6)
  end

  def render(assigns) do
    ~H"""
    <div class="home-container">
      <div class="bento-card">
        <%= if @current_user do %>
          <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--line-color); padding-bottom: 15px; margin-bottom: 30px;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <span class="user-badge" style="margin: 0;">Resident: <%= @current_user.name %></span>
              <.link navigate={~p"/users/settings"} title="Edit Profile" style="color: var(--text-main); display: flex; align-items: center; transition: opacity 0.2s;" onmouseover="this.style.opacity='0.6'" onmouseout="this.style.opacity='1'">
                <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>
              </.link>
            </div>
            <div>
              <.link href={~p"/users/log_out"} method="delete" style="color: var(--text-muted); font-size: 0.9rem; text-decoration: none; font-family: 'Lato', sans-serif;">Sign Out</.link>
            </div>
          </div>
        <% end %>

        <h1>The Daily Ledger</h1>
        <p>A minimalist ledger for household chores.</p>

        <%= if is_nil(@current_user) do %>
          <div style="margin-top: 50px;">
            <h3 style="font-family: 'Playfair Display', serif; font-size: 1.5rem; margin-bottom: 20px;">Identity Required</h3>
            <p style="font-family: 'Lato', sans-serif; font-size: 0.95rem; color: var(--text-muted); margin-bottom: 20px;">
              Please securely authenticate your identity to continue.
            </p>
            <div style="display: flex; gap: 10px;">
              <.link navigate={~p"/users/log_in"} style="flex: 1; padding: 15px; background: transparent; border: 1px solid var(--text-main); color: var(--text-main); text-align: center; text-decoration: none; text-transform: uppercase; letter-spacing: 2px; font-size: 0.9rem; font-family: 'Lato', sans-serif;">Sign In</.link>
              <.link navigate={~p"/users/register"} style="flex: 1; padding: 15px; background: var(--text-main); border: 1px solid var(--text-main); color: var(--bg-color); text-align: center; text-decoration: none; text-transform: uppercase; letter-spacing: 2px; font-size: 0.9rem; font-family: 'Lato', sans-serif;">Register</.link>
            </div>
          </div>
        <% else %>
          <%= if not Enum.empty?(@my_rooms) do %>
            <div style="margin-top: 30px;">
              <h3 style="font-family: 'Playfair Display', serif; font-size: 1.5rem; margin-bottom: 20px;">Your Ledgers</h3>
              <div style="display: flex; flex-direction: column; gap: 10px;">
                <%= for {name, code, is_super} <- @my_rooms do %>
                  <.link navigate={~p"/room/#{code}"} style="display: flex; justify-content: space-between; align-items: center; padding: 15px; border: 1px solid var(--line-color); text-decoration: none; color: var(--text-main); transition: background 0.2s;" onmouseover="this.style.background='rgba(0,0,0,0.05)'" onmouseout="this.style.background='transparent'">
                    <span style="font-family: 'Playfair Display', serif; font-size: 1.2rem; font-style: italic;"><%= name %></span>
                    <%= if is_super do %>
                      <span style="color: #b45309; font-size: 0.8rem; font-weight: bold; text-transform: uppercase; letter-spacing: 1px;">Super User</span>
                    <% else %>
                      <span style="color: var(--text-muted); font-size: 0.8rem; text-transform: uppercase; letter-spacing: 1px;">Member</span>
                    <% end %>
                  </.link>
                <% end %>
              </div>
            </div>
          <% end %>

          <div style="margin-top: 40px; border-top: 1px solid var(--line-color); padding-top: 40px;">
            <h3 style="font-family: 'Playfair Display', serif; font-size: 1.5rem; margin-bottom: 20px;">Join Existing</h3>
            <form phx-submit="join_room">
              <input type="text" name="room_code" placeholder="Enter the 6-character invite code" required autocomplete="off" style="text-transform: uppercase;" />
              <button type="submit">Enter</button>
            </form>
          </div>

          <div style="margin-top: 40px; border-top: 1px solid var(--line-color); padding-top: 40px;">
            <h3 style="font-family: 'Playfair Display', serif; font-size: 1.5rem; margin-bottom: 20px;">Establish New</h3>
            <p style="font-family: 'Lato', sans-serif; font-size: 0.95rem; color: var(--text-muted); margin-bottom: 20px; text-align: left;">
              Create a pristine ledger for a new household.
            </p>
            <form phx-submit="create_room">
              <input type="text" name="name" placeholder="Name of the apartment (e.g. The Progati)" required autocomplete="off" />
              <button type="submit" style="background: transparent; color: var(--text-main); border: 1px solid var(--text-main);">Create Ledger</button>
            </form>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
