

-- ============================================
-- Arena Shooter Database Setup
-- MySQL 8.0+
-- ============================================

-- Create database
CREATE DATABASE IF NOT EXISTS arena_shooter;
USE arena_shooter;


-- ============================================
-- Table: users
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    current_dress VARCHAR(50) DEFAULT 'Default',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Table: player_stats
-- ============================================
CREATE TABLE IF NOT EXISTS player_stats (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    total_kills INT DEFAULT 0,
    high_score INT DEFAULT 0,
    health INT DEFAULT 100,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Table: inventory
-- ============================================
CREATE TABLE IF NOT EXISTS inventory (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    primary_weapon VARCHAR(50) DEFAULT 'AKM',
    secondary_weapon VARCHAR(50) DEFAULT 'UZI',
    first_aid_count INT DEFAULT 0,
    medkit_count INT DEFAULT 0,
    boost_count INT DEFAULT 0,
    helmet_level INT DEFAULT 1,
    vest_level INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Seed Data (Sample Users)
-- ============================================
INSERT INTO users (username, password, current_dress) VALUES
('player1', 'password123', 'Default'),
('player2', 'password123', 'Camo'),
('testuser', 'test', 'Urban')
ON DUPLICATE KEY UPDATE username=username;

-- Seed player_stats
INSERT INTO player_stats (user_id, total_kills, high_score, health)
SELECT id, 0, 0, 100 FROM users WHERE username = 'player1'
ON DUPLICATE KEY UPDATE user_id=user_id;

INSERT INTO player_stats (user_id, total_kills, high_score, health)
SELECT id, 5, 500, 100 FROM users WHERE username = 'player2'
ON DUPLICATE KEY UPDATE user_id=user_id;

INSERT INTO player_stats (user_id, total_kills, high_score, health)
SELECT id, 0, 0, 100 FROM users WHERE username = 'testuser'
ON DUPLICATE KEY UPDATE user_id=user_id;

-- Seed inventory
INSERT INTO inventory (user_id, primary_weapon, secondary_weapon, first_aid_count, medkit_count, boost_count, helmet_level, vest_level)
SELECT id, 'AKM', 'UZI', 1, 0, 1, 1, 1 FROM users WHERE username = 'player1'
ON DUPLICATE KEY UPDATE user_id=user_id;

INSERT INTO inventory (user_id, primary_weapon, secondary_weapon, first_aid_count, medkit_count, boost_count, helmet_level, vest_level)
SELECT id, 'M416', 'Shotgun', 2, 1, 2, 2, 2 FROM users WHERE username = 'player2'
ON DUPLICATE KEY UPDATE user_id=user_id;

INSERT INTO inventory (user_id, primary_weapon, secondary_weapon, first_aid_count, medkit_count, boost_count, helmet_level, vest_level)
SELECT id, 'AKM', 'UMP', 0, 0, 0, 1, 1 FROM users WHERE username = 'testuser'
ON DUPLICATE KEY UPDATE user_id=user_id;

-- ============================================
-- Verify Setup
-- ============================================
SELECT 'Database setup complete!' AS status;
SELECT COUNT(*) AS total_users FROM users;
SELECT COUNT(*) AS total_stats FROM player_stats;
SELECT COUNT(*) AS total_inventories FROM inventory;

-- ============================================
-- Sample Queries for Testing
-- ============================================

-- Get full player profile
-- SELECT 
--     u.id, u.username, u.current_dress,
--     ps.total_kills, ps.high_score, ps.health,
--     i.primary_weapon, i.secondary_weapon, 
--     i.first_aid_count, i.medkit_count, i.boost_count,
--     i.helmet_level, i.vest_level
-- FROM users u
-- LEFT JOIN player_stats ps ON u.id = ps.user_id
-- LEFT JOIN inventory i ON u.id = i.user_id
-- WHERE u.username = 'player1';

-- Update stats example
-- UPDATE player_stats SET total_kills = total_kills + 1, high_score = 1000 WHERE user_id = 1;

-- Update inventory example
-- UPDATE inventory SET first_aid_count = 5, helmet_level = 3 WHERE user_id = 1;
