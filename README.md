# Vortex Arena — AOOP Award Project (3rd Prize)

Vortex Arena is my **AOOP (Advanced Object-Oriented Programming)** project that won **3rd Prize**. It’s an arena-shooter backend built around a clean layered architecture and a real-time multiplayer loop.

This repository contains the **Spring Boot server**, **MySQL schema/migrations**, and the full gameplay/persistence systems (profiles, inventory, ELO, seasons, tournaments, achievements, economy, match history, and replay events).

> Note: this repo focuses on the **backend + real-time game protocol**. A client (web/desktop) can connect via REST + WebSocket and render the match.

---

## Tech Stack

- **Java 17**
- **Spring Boot 3.5.8**
  - REST APIs (controllers)
  - WebSockets for real-time gameplay
  - Spring Data JPA for persistence
- **MySQL 8.0+**
- **Gradle** (wrapper included)

Architecture: **Controller → Service → Repository → Database**

---

## How the Project Works (High-Level)

### 1) Authentication + Player Profile
- `POST /auth/login` accepts a username/password.
- If the user doesn’t exist, the server **auto-registers** them (AOOP demo convenience).
- On first login, the server ensures default rows exist:
  - `player_stats` (kills, score, ELO, tier, etc.)
  - `inventory` (starter weapons + items)
  - `currency_wallet` (coins/gems)

### 2) Real-Time Multiplayer (WebSocket)
The realtime game loop is modeled as a **single global lobby/match** (`matchId = "GLOBAL"`) managed in memory:
- Players connect to: `ws://localhost:7320/ws/multiplayer`
- Clients exchange JSON messages with a `type`, `senderId`, and optional `payload`.

Core client → server message types:
- `JOIN`, `LEAVE`, `READY`
- `MOVE`, `SHOOT`, `HIT_PLAYER`
- `ZOMBIE_KILL`, `RESPAWN`
- `CHAT`
- `SPECTATE`, `SPECTATE_SWITCH`

The server broadcasts events such as:
- lobby snapshots, ready states, match start/end
- movement, shots, damage, kills
- scoreboard + time updates

There is also a legacy/simple endpoint `ws://localhost:7320/ws/game` driven by a scheduled tick (`GameLoop`) that pushes basic state.

### 3) Match End Pipeline (Persistence + Progression)
When a match ends, the server runs a post-match pipeline:
1. **Match history** is recorded for each player (placement/result/kills, etc.)
2. **Economy rewards** are granted (coins/gems) with idempotency protection
3. **ELO rating** is updated with a standard expected-score formula and tier mapping
4. Aggregate stats (kills/deaths/damage) are updated
5. **Achievements** are checked/unlocked and rewards are credited

### 4) Replay System
During gameplay, timestamped events (MOVE/SHOOT/HIT/KILL/RESPAWN/…) can be recorded into `match_events`. A client can fetch events and reconstruct a replay.

---

## Project Structure (Key Parts)

```
Vortex-Arena-main/
├── src/main/java/com/example/arenashooter/
│   ├── controller/        # REST endpoints
│   ├── service/           # Game logic + progression systems
│   ├── multiplayer/       # MatchState/PlayerState + multiplayer WebSocket
│   ├── websocket/         # Legacy single-player handler
│   └── config/            # WebSocket configuration
├── src/main/resources/
│   ├── application.properties
│   └── application.properties.example
├── database/
│   ├── schema.sql         # v1 schema + seed users
│   └── migration_v2.sql   # economy, cosmetics, achievements, ELO, seasons, tournaments, replay
└── build.gradle
```

---

## Setup (Local)

### 1) Database
1. Install **MySQL 8+** and start it.
2. Create tables:

```bash
mysql -u root -p < database/schema.sql
mysql -u root -p < database/migration_v2.sql
```

### 2) Configure DB credentials (no secrets committed)
This project reads DB settings from environment variables.

Example:
```bash
export DB_HOST=localhost
export DB_PORT=3306
export DB_NAME=arena_shooter
export DB_USER=root
export DB_PASS='your_password'
```

### 3) Run the server
```bash
# macOS/Linux
./gradlew bootRun

# Windows
.\gradlew.bat bootRun
```

Server default: `http://localhost:7320`

---

## API Surface (Summary)

### Auth
- `POST /auth/login`
- `POST /auth/register`

### Core profile / inventory
- `GET /api/player/profile?userId=...`
- `POST /api/sync-inventory`
- `POST /api/swap-weapons`
- `POST /api/heal`

### Leaderboards / ELO
- `GET /api/leaderboard`
- `GET /api/elo/profile?userId=...`
- `GET /api/elo/leaderboard`

### Economy / Cosmetics / Achievements
- `GET /api/economy/wallet?userId=...`
- `POST /api/economy/reward`
- `GET /api/cosmetics`
- `POST /api/cosmetics/unlock`
- `POST /api/cosmetics/equip`
- `POST /api/cosmetics/unequip`
- `GET /api/achievements?userId=...`
- `POST /api/achievements/check?userId=...`

### Seasons / Tournaments
- `GET /api/seasons/current`
- `GET /api/seasons/{seasonId}/leaderboard`
- `POST /api/seasons/{seasonId}/snapshot`
- `POST /api/seasons/new`
- `POST /api/tournaments`
- `GET /api/tournaments`
- `GET /api/tournaments/{id}`
- `POST /api/tournaments/{id}/join`
- `POST /api/tournaments/{id}/bracket`
- `POST /api/tournaments/matches/{matchId}/result`

### Match history / Replay
- `GET /api/history?playerId=...`
- `GET /api/history/match/{matchId}`
- `GET /api/replays/{matchId}`
- `GET /api/replays/{matchId}/player/{playerId}`
- `GET /api/replays/{matchId}/type/{eventType}`

---

## WebSocket (Multiplayer) Message Example

Connect:
- `ws://localhost:7320/ws/multiplayer`

Join payload:
```json
{
  "type": "JOIN",
  "senderId": "1",
  "payload": { "username": "player1" }
}
```

---

## Security / Disclaimer

This is an **educational AOOP project**:
- Authentication uses simple username/password without Spring Security.
- Password handling is not production-grade.

---

## Author

Shadhin Nandi
