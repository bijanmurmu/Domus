# Domus

*Domus* (Latin for "home") is an elegant, real-time ledger for tracking domestic responsibilities. Built with Elixir, Phoenix LiveView, and a custom high-end editorial design system, it provides a seamless and permanent audit trail of shared apartment chores.

## Features
- **Real-Time Sync:** Instant updates across all devices via Phoenix PubSub.
- **Room Isolation:** Independent, isolated instances for different apartments via room codes.
- **Historical Ledger:** A strict, chronological log of all completed chores with undo capabilities.
- **The Laureates:** An all-time leaderboard tracking roommate contributions.
- **Editorial UI:** A magazine-style, ultra-minimalist interface with custom SVG iconography and pure CSS.

## Getting Started

### Prerequisites
- Elixir 1.14+
- Erlang/OTP 25+

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/domus.git
   cd domus
   ```
2. Install dependencies:
   ```bash
   mix deps.get
   ```
3. Setup the database (SQLite):
   ```bash
   mix ecto.setup
   ```
4. Start the Phoenix server:
   ```bash
   mix phx.server
   ```
5. Open [`localhost:4000`](http://localhost:4000) in your browser.

## Tech Stack
- **Backend:** Elixir, Phoenix, Ecto
- **Database:** SQLite3
- **Frontend:** Phoenix LiveView, Custom Vanilla CSS

## License
This project is open-sourced under the MIT License. See [LICENSE](LICENSE) for details.
