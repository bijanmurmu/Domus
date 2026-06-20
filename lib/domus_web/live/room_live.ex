defmodule DomusWeb.RoomLive do
  use DomusWeb, :live_view
  import Ecto.Query, only: [from: 2]

  def mount(%{"room_code" => room_code}, _session, socket) do
    room = Domus.Repo.get_by(Domus.Tracking.Room, code: String.upcase(room_code))

    if room do
      if connected?(socket), do: DomusWeb.Endpoint.subscribe("room:#{room.code}")

      user = socket.assigns[:current_user]
      member = if user, do: Domus.Repo.get_by(Domus.Tracking.RoomMember, user_id: user.id, room_id: room.id), else: nil

      if member do
        local_now = DateTime.add(DateTime.utc_now(), 19800, :second)
        today = DateTime.to_date(local_now)

        socket = 
          socket
          |> assign(room: room)
          |> assign(room_code: room.code)
          |> assign(is_super_user: member.is_super_user)
          |> assign(name: user.name)
          |> assign(chores: ["Water Plants", "Sweep Floors", "Mop Floors", "Clean Bathroom"])
          |> assign(today: today)
          |> assign(selected_date: today)
          |> assign(calendar_month: today)
          |> assign(show_calendar: false)
          |> load_data()

        {:ok, socket}
      else
        {:ok, socket |> put_flash(:error, "You must join the room using the invite code on the Home page.") |> push_navigate(to: ~p"/")}
      end
    else
      {:ok, socket |> put_flash(:error, "Room not found.") |> push_navigate(to: ~p"/")}
    end
  end

  defp load_data(socket) do
    room_code = socket.assigns.room_code
    room_id = socket.assigns.room.id
    
    logs = Domus.Repo.all(
      from l in Domus.Tracking.Log,
      where: l.room_code == ^room_code,
      order_by: [desc: l.inserted_at],
      limit: 100
    )

    pending_logs = Domus.Repo.all(
      from l in Domus.Tracking.Log,
      where: l.room_code == ^room_code and is_nil(l.approved_by),
      order_by: [desc: l.inserted_at]
    )
    
    approved_logs = Domus.Repo.all(
      from l in Domus.Tracking.Log,
      where: l.room_code == ^room_code and not is_nil(l.approved_by),
      select: {l.roommate_name, l.chore}
    )

    leaderboard = Enum.reduce(approved_logs, %{}, fn {name, chore}, acc -> 
      clean_name = normalize_name(name)
      acc
      |> Map.update(clean_name, %{total: 1, chores: %{chore => 1}}, fn stats ->
        %{
          total: stats.total + 1,
          chores: Map.update(stats.chores, chore, 1, &(&1 + 1))
        }
      end)
    end)
    |> Enum.sort_by(fn {_name, stats} -> stats.total end, :desc)

    members = Domus.Repo.all(
      from rm in Domus.Tracking.RoomMember,
      where: rm.room_id == ^room_id,
      join: u in Domus.Accounts.User, on: rm.user_id == u.id,
      select: {rm.id, u.name, rm.is_super_user}
    )

    socket
    |> assign(:logs, logs)
    |> assign(:pending_logs, pending_logs)
    |> assign(:leaderboard, leaderboard)
    |> assign(:members, members)
  end

  defp normalize_name(name) do
    name
    |> String.trim()
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def handle_event("log_chore", %{"chore" => chore}, socket) do
    insert_log(socket, chore, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
  end

  def handle_event("log_past", params, socket) do
    chore = params["chore"] || List.first(socket.assigns.chores)
    date = socket.assigns.selected_date || Date.utc_today()
    datetime = NaiveDateTime.new!(date, ~T[12:00:00])
    insert_log(socket, chore, datetime)
  end

  def handle_event("prev_month", _, socket) do
    date = socket.assigns.calendar_month
    prev = Date.add(Date.beginning_of_month(date), -1)
    {:noreply, assign(socket, calendar_month: prev)}
  end

  def handle_event("next_month", _, socket) do
    date = socket.assigns.calendar_month
    next = Date.add(Date.end_of_month(date), 1)
    {:noreply, assign(socket, calendar_month: next)}
  end

  def handle_event("select_date", %{"date" => d}, socket) do
    case Date.from_iso8601(d) do
      {:ok, date} ->
        {:noreply, assign(socket, selected_date: date, show_calendar: false)}
      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_calendar", _, socket) do
    {:noreply, assign(socket, show_calendar: !socket.assigns.show_calendar)}
  end

  def handle_event("approve_log", %{"id" => id_str}, socket) do
    room_code = socket.assigns.room_code
    name = socket.assigns.name
    
    if name do
      clean_current_name = normalize_name(name)
      case Integer.parse(id_str) do
        {id, _} ->
          case Domus.Repo.get(Domus.Tracking.Log, id) do
            nil -> {:noreply, socket}
            log ->
              log_name = normalize_name(log.roommate_name)
              if log.room_code == room_code and is_nil(log.approved_by) and log_name != clean_current_name do
                log
                |> Ecto.Changeset.change(approved_by: clean_current_name)
                |> Domus.Repo.update!()
                
                DomusWeb.Endpoint.broadcast_from(self(), "room:#{room_code}", "new_log", %{})
                {:noreply, load_data(socket)}
              else
                {:noreply, socket}
              end
          end
        :error ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_log", %{"id" => id_str}, socket) do
    room_code = socket.assigns.room_code
    is_super_user = socket.assigns.is_super_user
    current_name = socket.assigns.name

    case Integer.parse(id_str) do
      {id, _} ->
        case Domus.Repo.get(Domus.Tracking.Log, id) do
          nil -> {:noreply, socket}
          log ->
            if log.room_code == room_code do
              if is_super_user or (current_name && normalize_name(current_name) == normalize_name(log.roommate_name)) do
                Domus.Repo.delete!(log)
                DomusWeb.Endpoint.broadcast_from(self(), "room:#{room_code}", "new_log", %{})
                {:noreply, load_data(socket)}
              else
                {:noreply, socket |> put_flash(:error, "You do not have permission to delete this log.")}
              end
            else
              {:noreply, socket}
            end
        end
      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("promote_member", %{"id" => id_str}, socket) do
    if socket.assigns.is_super_user do
      case Integer.parse(id_str) do
        {id, _} ->
          member = Domus.Repo.get(Domus.Tracking.RoomMember, id)
          if member && member.room_id == socket.assigns.room.id do
            member
            |> Domus.Tracking.RoomMember.changeset(%{is_super_user: true})
            |> Domus.Repo.update!()
            
            DomusWeb.Endpoint.broadcast_from(self(), "room:#{socket.assigns.room_code}", "new_log", %{})
            {:noreply, load_data(socket)}
          else
            {:noreply, socket}
          end
        :error ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("leave_room", _params, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room.id

    member = Domus.Repo.get_by(Domus.Tracking.RoomMember, user_id: user.id, room_id: room_id)
    if member do
      Domus.Repo.delete!(member)
      DomusWeb.Endpoint.broadcast_from(self(), "room:#{socket.assigns.room_code}", "new_log", %{})
      {:noreply, push_navigate(socket, to: ~p"/")}
    else
      {:noreply, push_navigate(socket, to: ~p"/")}
    end
  end

  def handle_event("delete_room", _params, socket) do
    if socket.assigns.is_super_user do
      room = socket.assigns.room
      room_code = socket.assigns.room_code
      
      # Manually delete all members and logs associated with the room to maintain referential integrity
      import Ecto.Query
      
      Domus.Repo.delete_all(from m in Domus.Tracking.RoomMember, where: m.room_id == ^room.id)
      Domus.Repo.delete_all(from l in Domus.Tracking.Log, where: l.room_code == ^room_code)
      Domus.Repo.delete!(room)

      {:noreply, push_navigate(socket, to: ~p"/") |> put_flash(:info, "Ledger permanently deleted.")}
    else
      {:noreply, socket |> put_flash(:error, "Only super users can delete the ledger.")}
    end
  end

  defp insert_log(socket, chore, datetime) do
    name = socket.assigns.name
    room_code = socket.assigns.room_code
    is_super = socket.assigns.is_super_user
    
    if name do
      clean_name = normalize_name(name)
      approved_by = if is_super, do: clean_name, else: nil
      
      case Domus.Repo.insert(%Domus.Tracking.Log{room_code: room_code, roommate_name: clean_name, chore: chore, inserted_at: datetime, updated_at: datetime, approved_by: approved_by}) do
        {:ok, _log} -> 
          DomusWeb.Endpoint.broadcast_from(self(), "room:#{room_code}", "new_log", %{})
          {:noreply, load_data(socket)}
        _ -> 
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "new_log"}, socket) do
    {:noreply, load_data(socket)}
  end

  defp format_pretty_date(date) do
    months = %{1 => "January", 2 => "February", 3 => "March", 4 => "April", 5 => "May", 6 => "June", 7 => "July", 8 => "August", 9 => "September", 10 => "October", 11 => "November", 12 => "December"}
    "#{months[date.month]} #{date.day}, #{date.year}"
  end

  defp format_month_year(date) do
    months = %{1 => "Jan", 2 => "Feb", 3 => "Mar", 4 => "Apr", 5 => "May", 6 => "Jun", 7 => "Jul", 8 => "Aug", 9 => "Sep", 10 => "Oct", 11 => "Nov", 12 => "Dec"}
    "#{months[date.month]} #{date.year}"
  end

  defp calendar_days(date) do
    first_day = Date.beginning_of_month(date)
    last_day = Date.end_of_month(date)
    
    start_pad = rem(Date.day_of_week(first_day), 7)
    
    days = Enum.map(1..last_day.day, fn d -> %{day: d, date: %Date{first_day | day: d}} end)
    
    List.duplicate(nil, start_pad) ++ days
  end

  def render(assigns) do
    local_now = DateTime.add(DateTime.utc_now(), 19800, :second)
    today_str = Date.to_string(DateTime.to_date(local_now))
    assigns = assign(assigns, today_str: today_str)

    ~H"""
    <div class="room-container">
      <%= if @name do %>
        <div style="display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 15px; border-bottom: 1px solid var(--line-color); padding-bottom: 15px; margin-bottom: 30px;">
          <div style="display: flex; flex-wrap: wrap; align-items: center; gap: 10px;">
            <div class="user-badge" style="margin: 0;">Resident: <%= @name %><%= if @is_super_user, do: " (Super User)" %></div>
            <.link navigate={~p"/users/settings"} title="Edit Profile" style="color: var(--text-main); display: flex; align-items: center; transition: opacity 0.2s;" onmouseover="this.style.opacity='0.6'" onmouseout="this.style.opacity='1'">
              <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>
            </.link>
          </div>
          <div style="display: flex; flex-wrap: wrap; gap: 15px; align-items: center;">
            <%= if @is_super_user do %>
              <button phx-click="delete_room" data-confirm="CRITICAL: Are you sure you want to PERMANENTLY destroy this ledger? All history and members will be deleted. This cannot be undone." style="background: none; border: none; padding: 0; color: #cc0000; font-size: 0.9rem; font-weight: bold; cursor: pointer; text-decoration: underline; font-family: 'Lato', sans-serif; width: auto; box-shadow: none;">Delete Ledger</button>
            <% end %>
            <button phx-click="leave_room" data-confirm="Are you sure you want to permanently leave this ledger?" style="background: none; border: none; padding: 0; color: var(--text-muted); font-size: 0.9rem; font-weight: normal; cursor: pointer; text-decoration: underline; font-family: 'Lato', sans-serif; width: auto; box-shadow: none;">Leave Room</button>
            <.link href={~p"/users/log_out"} method="delete" style="color: var(--text-muted); font-size: 0.9rem; text-decoration: none; font-family: 'Lato', sans-serif;">Sign Out</.link>
          </div>
        </div>
      <% end %>

      <div class="header" style="align-items: flex-start; display: block;">
        <div style="width: 100%;">
          <div style="display: flex; align-items: center; justify-content: space-between;">
            <h2 style="display: flex; align-items: center; gap: 15px;">
              <a href="/" style="text-decoration: none; color: var(--text-main); font-size: 2rem;">&larr;</a> 
              <%= @room.name %>
            </h2>
          </div>
          <div style="font-family: 'Lato', sans-serif; font-size: 0.95rem; margin-top: 10px; display: flex; align-items: center; gap: 8px;">
            <span style="color: var(--text-muted);">Invite Code:</span> 
            <strong style="background: var(--text-main); color: var(--bg-color); padding: 4px 10px; border-radius: 4px; letter-spacing: 2px;">
              <%= @room.code %>
            </strong>
            <button 
              id={"copy-btn-#{@room.code}"}
              phx-hook="CopyCode"
              data-code={@room.code}
              style="background: transparent; border: none; color: var(--text-muted); cursor: pointer; padding: 6px; display: inline-flex; align-items: center; justify-content: center; border-radius: 4px; transition: all 0.2s; box-shadow: none; width: auto;"
              onmouseover="this.style.color='var(--text-main)'; this.style.background='rgba(0,0,0,0.05)';"
              onmouseout="this.style.color='var(--text-muted)'; this.style.background='transparent';"
              title="Copy to clipboard"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
              </svg>
            </button>
          </div>
          
          <div style="margin-top: 20px; padding: 10px; border: 1px solid var(--line-color); display: inline-block;">
            <h4 style="font-size: 0.8rem; text-transform: uppercase; letter-spacing: 1px; color: var(--text-muted); margin-bottom: 10px;">Registered Residents</h4>
            <ul style="list-style: none; padding: 0; margin: 0; font-family: 'Playfair Display', serif; font-size: 1.1rem; display: flex; flex-direction: column; gap: 5px;">
              <%= for {member_id, name, is_super} <- @members do %>
                <li style="display: flex; align-items: center; gap: 10px;">
                  <span><%= name %></span>
                  <%= if is_super do %>
                    <span style="color: #b45309; font-size: 0.7rem; text-transform: uppercase; letter-spacing: 1px; font-family: 'Lato', sans-serif;">(Super)</span>
                  <% else %>
                    <%= if @is_super_user do %>
                      <button phx-click="promote_member" phx-value-id={member_id} style="background: none; border: none; padding: 0; color: #15803d; font-size: 0.7rem; font-weight: bold; cursor: pointer; text-transform: uppercase; letter-spacing: 1px; box-shadow: none; font-family: 'Lato', sans-serif; width: auto;" title="Make Super User">[Promote]</button>
                    <% end %>
                  <% end %>
                </li>
              <% end %>
            </ul>
          </div>

        </div>
      </div>

      <% pending_for_me = Enum.filter(@pending_logs, fn log -> @name && normalize_name(@name) != normalize_name(log.roommate_name) end) %>
      <%= if not Enum.empty?(pending_for_me) do %>
        <div style="background: rgba(180, 83, 9, 0.05); border: 1px solid rgba(180, 83, 9, 0.3); padding: 20px; margin-bottom: 40px; border-radius: 4px;">
          <h4 style="color: #b45309; font-family: 'Playfair Display', serif; font-size: 1.4rem; margin-bottom: 15px; display: flex; align-items: center; gap: 10px;">
            <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path><path d="M13.73 21a2 2 0 0 1-3.46 0"></path></svg>
            Pending Verifications
          </h4>
          <ul style="list-style: none; padding: 0; margin: 0; font-family: 'Lato', sans-serif; font-size: 0.95rem;">
            <%= for log <- pending_for_me do %>
              <li style="display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 15px; padding: 10px 0; border-bottom: 1px dashed rgba(180, 83, 9, 0.2);">
                <span><strong style="color: var(--text-main);"><%= normalize_name(log.roommate_name) %></strong> recorded <em style="font-family: 'Playfair Display', serif; font-size: 1.1rem; color: var(--text-main);"><%= log.chore %></em></span>
                <div style="display: flex; gap: 10px;">
                  <button phx-click="approve_log" phx-value-id={log.id} style="background: #15803d; color: white; border: none; padding: 6px 15px; border-radius: 2px; cursor: pointer; text-transform: uppercase; font-size: 0.75rem; font-weight: bold; letter-spacing: 1px; transition: opacity 0.2s;" onmouseover="this.style.opacity='0.8'" onmouseout="this.style.opacity='1'">Verify</button>
                  <%= if @is_super_user do %>
                    <button phx-click="delete_log" phx-value-id={log.id} style="background: transparent; color: #cc0000; border: 1px solid #cc0000; padding: 6px 15px; border-radius: 2px; cursor: pointer; text-transform: uppercase; font-size: 0.75rem; font-weight: bold; letter-spacing: 1px; transition: all 0.2s;" onmouseover="this.style.background='#cc0000'; this.style.color='white';" onmouseout="this.style.background='transparent'; this.style.color='#cc0000';">Reject & Delete</button>
                  <% end %>
                </div>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <div class="editorial-section">
        <h3>The Laureates</h3>
        <div class="stat-blocks">
          <%= for {person, stats} <- @leaderboard do %>
            <div class="stat-block">
              <div class="stat-name"><%= person %></div>
              <div class="stat-count"><%= stats.total %></div>
              <div class="stat-label">Contributions</div>
              
              <div style="margin-top: 20px; text-align: left; border-top: 1px solid rgba(0,0,0,0.1); padding-top: 15px;">
                <h4 style="font-size: 0.8rem; text-transform: uppercase; letter-spacing: 1px; color: var(--text-muted); margin-bottom: 10px;">The Ledger</h4>
                <ul style="list-style: none; padding: 0; margin: 0; font-family: 'Lato', sans-serif; font-size: 0.9rem;">
                  <%= for {chore, count} <- stats.chores do %>
                    <li style="display: flex; justify-content: space-between; margin-bottom: 5px; border-bottom: 1px dashed rgba(0,0,0,0.1); padding-bottom: 3px;">
                      <span><%= chore %></span>
                      <strong><%= count %></strong>
                    </li>
                  <% end %>
                </ul>
              </div>
            </div>
          <% end %>
          <%= if Enum.empty?(@leaderboard) do %>
            <div class="stat-block" style="width: 100%; border-right: 1px solid var(--line-color); background: transparent !important;">
              <p style="color: var(--text-main); text-align: center; margin: 0; font-family: 'Playfair Display', serif; font-style: italic; font-size: 1.2rem;">The ledger remains pristine.</p>
            </div>
          <% end %>
        </div>
      </div>

      <div class="editorial-section">
        <h3>Record an Action</h3>
        <div class="chores-grid">
          <%= for chore <- @chores do %>
            <button phx-click="log_chore" phx-value-chore={chore} class="chore-btn">
              <%= chore_icon(chore) %>
              <span><%= chore %></span>
            </button>
          <% end %>
        </div>
      </div>

      <div class="editorial-section">
        <h3>Historical Entry</h3>
        <form phx-submit="log_past" class="historical-form">
          <div class="form-group-flex">
            <select name="chore">
              <%= for chore <- @chores do %>
                <option value={chore}><%= chore %></option>
              <% end %>
            </select>
          </div>
          
          <div class="form-group-flex custom-calendar-wrapper" style="position: relative;">
            <div style="display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid var(--line-color); padding: 15px 0;">
              <span style="font-family: 'Playfair Display', serif; font-size: 1.1rem; font-style: italic;"><%= format_pretty_date(@selected_date) %></span>
              <button type="button" phx-click="toggle_calendar" style="background: none; border: none; color: var(--text-main); cursor: pointer; font-size: 0.8rem; text-transform: uppercase; letter-spacing: 1px; font-family: 'Lato', sans-serif; text-decoration: underline; padding: 0; box-shadow: none; width: auto;">Change Date</button>
            </div>
            
            <%= if @show_calendar do %>
              <div style="position: absolute; top: 100%; left: 0; width: 100%; background: var(--bg-color); border: 1px solid var(--line-color); border-top: none; z-index: 10; padding: 15px; box-shadow: 0 10px 30px rgba(0,0,0,0.1);">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; border-bottom: 1px solid var(--line-color); padding-bottom: 10px;">
                  <button type="button" phx-click="prev_month" style="background: transparent; border: none; font-size: 1.2rem; cursor: pointer; width: auto; box-shadow: none; color: var(--text-main);">&larr;</button>
                  <span style="font-family: 'Playfair Display', serif; font-size: 1.2rem; font-weight: bold; text-transform: uppercase; letter-spacing: 2px;"><%= format_month_year(@calendar_month) %></span>
                  <button type="button" phx-click="next_month" style="background: transparent; border: none; font-size: 1.2rem; cursor: pointer; width: auto; box-shadow: none; color: var(--text-main);">&rarr;</button>
                </div>
                
                <div style="display: grid; grid-template-columns: repeat(7, 1fr); text-align: center; font-family: 'Lato', sans-serif; font-size: 0.8rem; text-transform: uppercase; margin-bottom: 10px; color: var(--text-muted); font-weight: bold; letter-spacing: 1px;">
                  <span>Su</span><span>Mo</span><span>Tu</span><span>We</span><span>Th</span><span>Fr</span><span>Sa</span>
                </div>
                
                <div style="display: grid; grid-template-columns: repeat(7, 1fr); gap: 2px;">
                  <%= for item <- calendar_days(@calendar_month) do %>
                    <%= if is_nil(item) do %>
                      <div style="padding: 10px;"></div>
                    <% else %>
                      <% is_selected = item.date == @selected_date %>
                      <% is_future = Date.compare(item.date, @today) == :gt %>
                      <button 
                        type="button" 
                        phx-click={if not is_future, do: "select_date"} 
                        phx-value-date={item.date}
                        disabled={is_future}
                        style={
                          "padding: 10px 5px; font-family: 'Playfair Display', serif; font-size: 1.1rem; border: none; width: auto; box-shadow: none; transition: all 0.2s; " <>
                          if is_selected do
                            "background: var(--text-main); color: var(--bg-color); font-style: italic; cursor: default;"
                          else
                            if is_future do
                              "background: transparent; color: var(--text-muted); opacity: 0.3; cursor: not-allowed;"
                            else
                              "background: transparent; color: var(--text-main); cursor: pointer;"
                            end
                          end
                        }
                        onmouseover={if not is_selected and not is_future, do: "this.style.background='rgba(0,0,0,0.05)'"}
                        onmouseout={if not is_selected and not is_future, do: "this.style.background='transparent'"}
                      >
                        <%= item.day %>
                      </button>
                    <% end %>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <div class="form-group-btn">
            <button type="submit">Record</button>
          </div>
        </form>
      </div>

      <div class="editorial-section">
        <details class="ledger-dropdown">
          <summary style="font-family: 'Playfair Display', serif; font-size: 1.5rem; cursor: pointer; user-select: none; display: flex; justify-content: space-between; align-items: center; margin-bottom: 0;">
            <h3>Global Ledger History</h3>
            <span class="dropdown-icon" style="font-size: 1rem; color: var(--text-muted);">&#9660;</span>
          </summary>
          
          <div style="margin-top: 20px; background: rgba(0,0,0,0.02); padding: 15px; border: 1px solid var(--line-color); border-radius: 4px;">
            <ul class="terminal-log-list">
              <%= for log <- @logs do %>
                <li>
                  <span class="log-time">[<%= format_time_compact(log.inserted_at) %>]</span>
                  <span class="log-name"><%= normalize_name(log.roommate_name) %></span>
                  <span class="log-action">executed</span>
                  <span class="log-chore"><%= log.chore %></span>
                  
                  <%= if is_nil(log.approved_by) do %>
                    <span class="log-status unverified">pending</span>
                    <%= if @name && normalize_name(@name) != normalize_name(log.roommate_name) do %>
                      <button phx-click="approve_log" phx-value-id={log.id} class="log-btn approve-btn">Approve</button>
                    <% end %>
                  <% else %>
                    <span class="log-status verified">ok:<%= log.approved_by %></span>
                  <% end %>
                  
                  <%= if @is_super_user or (@name && normalize_name(@name) == normalize_name(log.roommate_name)) do %>
                    <button phx-click="delete_log" phx-value-id={log.id} class="log-btn delete-btn">Del</button>
                  <% end %>
                </li>
              <% end %>
              <%= if Enum.empty?(@logs) do %>
                <li style="color: var(--text-muted); justify-content: center; padding: 20px 0; font-family: 'Playfair Display', serif; font-style: italic;">Blank pages.</li>
              <% end %>
            </ul>
          </div>
        </details>
      </div>
    </div>
    """
  end

  defp format_time(datetime) do
    local_dt = NaiveDateTime.add(datetime, 19800, :second)
    
    date = NaiveDateTime.to_date(local_dt)
    time = NaiveDateTime.to_time(local_dt)
    
    hour = if time.hour == 0, do: 12, else: (if time.hour > 12, do: time.hour - 12, else: time.hour)
    am_pm = if time.hour >= 12, do: "PM", else: "AM"
    minute = String.pad_leading(Integer.to_string(time.minute), 2, "0")
    
    "#{date} — #{hour}:#{minute} #{am_pm}"
  end

  defp format_time_compact(datetime) do
    local_dt = NaiveDateTime.add(datetime, 19800, :second)
    
    date = NaiveDateTime.to_date(local_dt)
    time = NaiveDateTime.to_time(local_dt)
    
    "#{date.month}/#{date.day} #{String.pad_leading(Integer.to_string(time.hour), 2, "0")}:#{String.pad_leading(Integer.to_string(time.minute), 2, "0")}"
  end

  defp chore_icon("Water Plants") do
    assigns = %{}
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" class="chore-svg" width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z"/></svg>
    """
  end

  defp chore_icon("Sweep Floors") do
    assigns = %{}
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" class="chore-svg" width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"><path d="m9.06 11.9 8.07-8.06a2.85 2.85 0 1 1 4.03 4.03l-8.06 8.08"/><path d="M7.07 14.94c-1.66 0-3 1.35-3 3.02 0 1.33-2.5 1.52-2 2.02 1.08 1.1 2.49 2.02 4 2.02 2.2 0 4-1.8 4-4.04a3.01 3.01 0 0 0-3-3.02z"/></svg>
    """
  end

  defp chore_icon("Mop Floors") do
    assigns = %{}
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" class="chore-svg" width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"><path d="M2 6c.6.5 1.2 1 2.5 1C7 7 7 5 9.5 5c2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1"/><path d="M2 12c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1"/><path d="M2 18c.6.5 1.2 1 2.5 1 2.5 0 2.5-2 5-2 2.6 0 2.4 2 5 2 2.5 0 2.5-2 5-2 1.3 0 1.9.5 2.5 1"/></svg>
    """
  end

  defp chore_icon("Clean Bathroom") do
    assigns = %{}
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" class="chore-svg" width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"><path d="M9 6 6.5 3.5a1.5 1.5 0 0 0-1-.5C4.683 3 4 3.683 4 4.5V17a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-5"/><line x1="10" x2="8" y1="5" y2="7"/><line x1="2" x2="22" y1="12" y2="12"/><line x1="7" x2="7" y1="19" y2="21"/><line x1="17" x2="17" y1="19" y2="21"/></svg>
    """
  end
end
