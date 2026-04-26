# Vortex Arena - AI Coding Agent Instructions

## Project Overview
Vortex Arena is a 2D multiplayer arena shooter game with Spring Boot backend and vanilla JavaScript frontend. The architecture follows a stateless REST API pattern where the client synchronizes game state with the server for persistence.

## Architecture & Data Flow

### Backend Structure (Spring Boot 3.5.8, Java 17)
- **Layered architecture**: Controller → Service → Repository → Database
- **Key pattern**: No Lombok on entities (plain POJOs), but Lombok allowed elsewhere
- **Service layer** handles all business logic; controllers are thin REST endpoints
- **Entity relationships**: `User` ↔ `PlayerStats` (OneToOne), `User` ↔ `Inventory` (OneToOne)
- **Database**: MySQL 8.0+ (`arena_shooter` database on port 3306)

### Frontend-Backend Integration
- **Client-side game loop**: JavaScript Canvas runs game logic locally; server is source of truth for persistence
- **API calls**: Client POSTs to `/api/*` endpoints to sync inventory, update stats, handle kills, healing
- **State pattern**: `PlayerProfileDto` is the unified response format containing user, stats, and inventory
- **Critical**: Server runs on port **7320** (not default 8080) - see [application.properties](src/main/resources/application.properties#L7)

### Data Synchronization Points
1. **Login** (`/api/login`) - Returns full `PlayerProfileDto`
2. **Game start** (`/api/start?userId=X`) - Initializes/retrieves player state
3. **During gameplay**:
   - `/api/sync-inventory` - Syncs weapons, healing items, armor levels
   - `/api/update-stats` - Updates kills, score, health
   - `/api/handle-kill` - Increments kill count, updates high score
   - `/api/heal` - Applies healing and updates health
   - `/api/swap-weapons` - Changes primary/secondary weapon

## Key Conventions

### DTOs & Request/Response Pattern
- **All API methods return `PlayerProfileDto`** - contains userId, username, stats, inventory, currentDress
- Request DTOs always include `userId` as the primary identifier (e.g., `StatsUpdateRequest`, `InventorySyncRequest`)
- See [dto/](src/main/java/com/example/arenashooter/dto) for complete request/response contracts

### Service Layer Business Rules
- **Health clamping**: Always use `clamp(value, 0, 100)` to bound health (see [GameService.java](src/main/java/com/example/arenashooter/service/GameService.java#L68))
- **High score logic**: Use `Math.max(currentHighScore, newScore)` - never decrease
- **Default initialization**: If stats/inventory missing, create with defaults via `createDefaultStats()`/`createDefaultInventory()`

### Database Schema
- Primary schema: [database/schema.sql](database/schema.sql)
- **Seeded test users**: `player1`, `player2`, `testuser` (all password: `password123` or `test`)
- Foreign keys use `ON DELETE CASCADE` - deleting user removes stats and inventory
- Default weapon loadout: `AKM` (primary), `UZI` (secondary)

## Development Workflow

### Running the Application
```bash
# 1. Ensure MySQL is running and schema is loaded
mysql -u root -p < database/schema.sql

# 2. Update credentials in application.properties if needed
# Current: username=arena, password=arena123

# 3. Start backend (uses embedded Tomcat on port 7320)
.\gradlew.bat bootRun         # Windows
./gradlew bootRun             # Linux/Mac

# 4. Open browser to http://localhost:7320/index.html
```

### Testing & Debugging
- **Manual testing**: Use seeded users (`player1/password123`) for quick login
- **API testing**: Backend exposes REST endpoints at `http://localhost:7320/api/*`
- **Database inspection**: Query `arena_shooter` database to verify state persistence
- **Frontend debugging**: Open browser DevTools → Console to see API errors (`console.error` used throughout [game.js](src/main/resources/static/game.js))

### Making Changes

#### Adding New API Endpoints
1. Create DTO in [dto/](src/main/java/com/example/arenashooter/dto) with `userId` field
2. Add method to [GameService.java](src/main/java/com/example/arenashooter/service/GameService.java) - return `PlayerProfileDto`
3. Add REST endpoint to [GameController.java](src/main/java/com/example/arenashooter/controller/GameController.java)
4. Update frontend [game.js](src/main/resources/static/game.js) to call new endpoint with `fetch()`

#### Modifying Game Mechanics
- **Weapon stats**: Edit `WEAPON_DATA` object in [game.js](src/main/resources/static/game.js#L41) (damage, fireRate, magSize, etc.)
- **Map areas**: Modify `MAP_AREAS` array (8 Bangladesh divisions) for layout changes
- **Enemy spawning**: Adjust `ENEMY_SPAWN_INTERVAL` and `MAX_ENEMIES` constants

#### Database Changes
1. Modify [schema.sql](database/schema.sql) for table structure
2. Update corresponding entity in [entity/](src/main/java/com/example/arenashooter/entity)
3. Update DTOs if API contracts change
4. Set `spring.jpa.hibernate.ddl-auto=update` (already configured) to auto-apply changes

## Common Patterns to Follow

### Repository Queries
```java
// Always use Optional for single-entity queries
Optional<PlayerStats> findByUserId(Long userId);
// Service layer: .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "..."))
```

### Frontend API Calls
```javascript
// Pattern: POST with JSON body, expect PlayerProfileDto response
const response = await fetch(`${API_BASE}/endpoint`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId: playerProfile.userId, /* other fields */ })
});
if (response.ok) playerProfile = await response.json();
```

## External Dependencies
- **Spring Boot Starter Web** - REST API
- **Spring Boot Starter Data JPA** - Database ORM
- **MySQL Connector/J** - Database driver
- **Lombok** - Boilerplate reduction (NOT used on entities)
- **JUnit 5** - Testing framework

## File References
- Main app entry: [ArenaShooterApplication.java](src/main/java/com/example/arenashooter/ArenaShooterApplication.java)
- Game logic service: [GameService.java](src/main/java/com/example/arenashooter/service/GameService.java)
- API controllers: [controller/](src/main/java/com/example/arenashooter/controller)
- Frontend game engine: [game.js](src/main/resources/static/game.js)
- Database schema: [schema.sql](database/schema.sql)
