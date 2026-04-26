-- ============================================
-- Arena Shooter V2 Migration
-- Adds: Economy, Cosmetics, Achievements,
--       Match History, ELO, Seasons,
--       Tournaments, Replay Events
-- Compatible with existing schema
-- ============================================

USE arena_shooter;

-- ============================================
-- 1. Coin / Gem Economy
-- ============================================

CREATE TABLE IF NOT EXISTS currency_wallet (
    wallet_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    coins INT NOT NULL DEFAULT 0,
    gems INT NOT NULL DEFAULT 0,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS reward_transactions (
    txn_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    match_id VARCHAR(64) NOT NULL,
    coins_earned INT NOT NULL DEFAULT 0,
    gems_earned INT NOT NULL DEFAULT 0,
    reason VARCHAR(32) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_match (user_id, match_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- 2. Character Customization / Cosmetics
-- ============================================

CREATE TABLE IF NOT EXISTS cosmetics (
    cosmetic_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    type VARCHAR(20) NOT NULL DEFAULT 'SKIN',
    price INT NOT NULL DEFAULT 0,
    asset_path VARCHAR(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user_cosmetics (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    cosmetic_id BIGINT NOT NULL,
    is_equipped BOOLEAN NOT NULL DEFAULT FALSE,
    unlocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_cosmetic (user_id, cosmetic_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (cosmetic_id) REFERENCES cosmetics(cosmetic_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed default cosmetics
INSERT INTO cosmetics (name, type, price, asset_path) VALUES
('Default Skin', 'SKIN', 0, '/assets/skins/default.png'),
('Camo Warrior', 'SKIN', 500, '/assets/skins/camo.png'),
('Neon Ghost', 'SKIN', 1000, '/assets/skins/neon.png'),
('Fire Trail', 'EFFECT', 200, '/assets/effects/fire_trail.png'),
('Ice Aura', 'EFFECT', 300, '/assets/effects/ice_aura.png'),
('Shadow Cloak', 'SKIN', 1500, '/assets/skins/shadow.png'),
('Gold Plated', 'SKIN', 2000, '/assets/skins/gold.png'),
('Lightning Bolt', 'EFFECT', 750, '/assets/effects/lightning.png')
ON DUPLICATE KEY UPDATE name=name;

-- ============================================
-- 3. Achievement System
-- ============================================

CREATE TABLE IF NOT EXISTS achievements (
    achievement_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255) NOT NULL,
    reward_coins INT NOT NULL DEFAULT 0,
    reward_gems INT NOT NULL DEFAULT 0,
    condition_type VARCHAR(50) NOT NULL,
    condition_value INT NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user_achievements (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    achievement_id BIGINT NOT NULL,
    unlocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_achievement (user_id, achievement_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (achievement_id) REFERENCES achievements(achievement_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed achievements
INSERT INTO achievements (name, description, reward_coins, reward_gems, condition_type, condition_value) VALUES
('First Blood', 'Get your first kill', 50, 0, 'TOTAL_KILLS', 1),
('Rookie Slayer', 'Get 20 kills total', 200, 5, 'TOTAL_KILLS', 20),
('Veteran Killer', 'Get 100 kills total', 1000, 25, 'TOTAL_KILLS', 100),
('Centurion', 'Get 500 kills total', 5000, 100, 'TOTAL_KILLS', 500),
('First Victory', 'Win your first match', 100, 5, 'MATCHES_WON', 1),
('Winner Streak', 'Win 10 matches', 500, 25, 'MATCHES_WON', 10),
('Champion', 'Win 50 matches', 2500, 75, 'MATCHES_WON', 50),
('Bronze Reached', 'Reach Bronze tier', 100, 0, 'TIER_REACHED', 1),
('Silver Reached', 'Reach Silver tier', 250, 10, 'TIER_REACHED', 2),
('Gold Reached', 'Reach Gold tier', 500, 25, 'TIER_REACHED', 3),
('Platinum Reached', 'Reach Platinum tier', 1000, 50, 'TIER_REACHED', 4),
('Diamond Reached', 'Reach Diamond tier', 2500, 100, 'TIER_REACHED', 5),
('Master Reached', 'Reach Master tier', 5000, 250, 'TIER_REACHED', 6),
('Sharpshooter', 'Deal 10000 total damage', 300, 10, 'TOTAL_DAMAGE', 10000),
('Survivor', 'Play 100 matches', 1000, 50, 'MATCHES_PLAYED', 100)
ON DUPLICATE KEY UPDATE name=name;

-- ============================================
-- 4. Match History Tracking
-- ============================================

CREATE TABLE IF NOT EXISTS match_history (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    match_id VARCHAR(64) NOT NULL,
    player_id BIGINT NOT NULL,
    kills INT NOT NULL DEFAULT 0,
    deaths INT NOT NULL DEFAULT 0,
    damage INT NOT NULL DEFAULT 0,
    placement INT NOT NULL DEFAULT 0,
    result VARCHAR(10) NOT NULL DEFAULT 'LOSS',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_player (player_id),
    INDEX idx_match (match_id),
    FOREIGN KEY (player_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- 5. Skill-Based Ranking (ELO)
-- Adds columns to existing player_stats table
-- ============================================

ALTER TABLE player_stats
    ADD COLUMN IF NOT EXISTS elo_rating INT NOT NULL DEFAULT 1000,
    ADD COLUMN IF NOT EXISTS tier VARCHAR(20) NOT NULL DEFAULT 'BRONZE',
    ADD COLUMN IF NOT EXISTS matches_won INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS matches_played INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_deaths INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_damage INT NOT NULL DEFAULT 0;

-- ============================================
-- 6. Seasonal Leaderboard
-- ============================================

CREATE TABLE IF NOT EXISTS seasons (
    season_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT FALSE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS season_rankings (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    season_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    elo_snapshot INT NOT NULL DEFAULT 1000,
    rank_position INT NOT NULL DEFAULT 0,
    UNIQUE KEY uk_season_user (season_id, user_id),
    FOREIGN KEY (season_id) REFERENCES seasons(season_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Seed initial season
INSERT INTO seasons (name, start_date, end_date, is_active) VALUES
('Season 1 - Genesis', '2026-03-01', '2026-06-01', TRUE)
ON DUPLICATE KEY UPDATE name=name;

-- ============================================
-- 7. Tournament Mode
-- ============================================

CREATE TABLE IF NOT EXISTS tournaments (
    tournament_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'UPCOMING',
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    max_players INT NOT NULL DEFAULT 16,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tournament_participants (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    tournament_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    seed INT NOT NULL DEFAULT 0,
    eliminated BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE KEY uk_tourney_user (tournament_id, user_id),
    FOREIGN KEY (tournament_id) REFERENCES tournaments(tournament_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS tournament_matches (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    tournament_id BIGINT NOT NULL,
    match_id VARCHAR(64),
    round_number INT NOT NULL,
    player1_id BIGINT,
    player2_id BIGINT,
    winner_id BIGINT,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tournament_id) REFERENCES tournaments(tournament_id) ON DELETE CASCADE,
    FOREIGN KEY (player1_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (player2_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (winner_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- 9. Replay System (Match Events)
-- ============================================

CREATE TABLE IF NOT EXISTS match_events (
    event_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    match_id VARCHAR(64) NOT NULL,
    event_type VARCHAR(30) NOT NULL,
    player_id BIGINT,
    event_timestamp BIGINT NOT NULL,
    data_json JSON,
    INDEX idx_match_events (match_id),
    INDEX idx_match_player (match_id, player_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Create wallets for existing users
-- ============================================
INSERT IGNORE INTO currency_wallet (user_id, coins, gems)
SELECT id, 0, 0 FROM users;

-- ============================================
-- Verify Migration
-- ============================================
SELECT 'Migration V2 complete!' AS status;
