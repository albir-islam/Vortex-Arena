package com.example.arenashooter.multiplayer.model;

/**
 * Represents a player's current state in a multiplayer match.
 */
public class PlayerState {
    private String playerId;
    private String username;
    private double x;
    private double y;
    private double rotation;
    private int health;
    private int maxHealth;
    private int score;
    private int playerKills;
    private int zombieKills;
    private boolean alive;
    private boolean ready;

    public PlayerState() {
        this.health = 100;
        this.maxHealth = 100;
        this.score = 0;
        this.playerKills = 0;
        this.zombieKills = 0;
        this.alive = true;
        this.ready = false;
    }

    public PlayerState(String playerId, String username) {
        this();
        this.playerId = playerId;
        this.username = username;
    }

    // Getters and setters
    public String getPlayerId() { return playerId; }
    public void setPlayerId(String playerId) { this.playerId = playerId; }

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public double getX() { return x; }
    public void setX(double x) { this.x = x; }

    public double getY() { return y; }
    public void setY(double y) { this.y = y; }

    public double getRotation() { return rotation; }
    public void setRotation(double rotation) { this.rotation = rotation; }

    public int getHealth() { return health; }
    public void setHealth(int health) { this.health = Math.max(0, Math.min(health, maxHealth)); }

    public int getMaxHealth() { return maxHealth; }
    public void setMaxHealth(int maxHealth) { this.maxHealth = maxHealth; }

    public int getScore() { return score; }
    public void setScore(int score) { this.score = score; }
    public void addScore(int points) { this.score += points; }

    public int getPlayerKills() { return playerKills; }
    public void setPlayerKills(int playerKills) { this.playerKills = playerKills; }
    public void addPlayerKill() { this.playerKills++; }

    public int getZombieKills() { return zombieKills; }
    public void setZombieKills(int zombieKills) { this.zombieKills = zombieKills; }
    public void addZombieKill() { this.zombieKills++; }

    public boolean isAlive() { return alive; }
    public void setAlive(boolean alive) { this.alive = alive; }

    public boolean isReady() { return ready; }
    public void setReady(boolean ready) { this.ready = ready; }

    public void respawn(double spawnX, double spawnY) {
        this.x = spawnX;
        this.y = spawnY;
        this.health = maxHealth;
        this.alive = true;
    }

    public void takeDamage(int damage) {
        this.health = Math.max(0, this.health - damage);
        if (this.health <= 0) {
            this.alive = false;
        }
    }
}
