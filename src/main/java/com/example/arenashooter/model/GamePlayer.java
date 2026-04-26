package com.example.arenashooter.model;

import org.springframework.web.socket.WebSocketSession;

public class GamePlayer {
    private String playerId;
    private String username;
    private WebSocketSession session;
    private float x, y;
    private int health = 100;
    private int kills = 0;
    private boolean isDead = false;

    public GamePlayer(String playerId, String username, WebSocketSession session) {
        this.playerId = playerId;
        this.username = username;
        this.session = session;
    }

    public void updatePosition(float x, float y) {
        this.x = x;
        this.y = y;
    }

    public void takeDamage(int amount) {
        this.health -= amount;
        if (this.health <= 0) {
            this.health = 0;
            this.isDead = true;
        }
    }

    public void addKill() {
        this.kills++;
    }

    public String getPlayerId() {
        return playerId;
    }

    public String getUsername() {
        return username;
    }

    public WebSocketSession getSession() {
        return session;
    }

    public float getX() {
        return x;
    }

    public float getY() {
        return y;
    }

    public int getHealth() {
        return health;
    }

    public int getKills() {
        return kills;
    }

    public boolean isDead() {
        return isDead;
    }

    public void setDead(boolean dead) {
        isDead = dead;
    }
}
