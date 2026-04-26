package com.example.arenashooter.model;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.web.socket.WebSocketSession;

public class GameMatch {
    private String matchId;
    private Map<String, GamePlayer> players = new ConcurrentHashMap<>();
    private boolean isRunning = true;

    // Simple state: Key = playerId
    // Could eventually store bullets, obstacles, etc.

    public GameMatch(String matchId) {
        this.matchId = matchId;
    }

    public void addPlayer(String playerId, GamePlayer player) {
        players.put(playerId, player);
    }

    public void removePlayer(String playerId) {
        players.remove(playerId);
    }

    public GamePlayer getPlayer(String playerId) {
        return players.get(playerId);
    }

    public Map<String, GamePlayer> getPlayers() {
        return players;
    }

    public String getMatchId() {
        return matchId;
    }

    public boolean isRunning() {
        return isRunning;
    }

    public void setRunning(boolean running) {
        isRunning = running;
    }
}
