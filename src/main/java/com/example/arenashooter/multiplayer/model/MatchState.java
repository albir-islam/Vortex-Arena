package com.example.arenashooter.multiplayer.model;

import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.stream.Collectors;

/**
 * Represents a multiplayer match/lobby state.
 * Max 3 players per match.
 */
public class MatchState {
    public enum Status {
        WAITING,   // Waiting for players to ready up
        IN_PROGRESS, // Match is running
        FINISHED   // Match has ended
    }

    private final String matchId;
    private Status status;
    private final ConcurrentHashMap<String, PlayerState> players;
    private final List<ChatMessage> chatHistory;
    private long startTime;
    private long endTime;
    private static final int MATCH_DURATION_SECONDS = 300; // 5 minutes
    private static final int MAX_PLAYERS = 3;

    public MatchState(String matchId) {
        this.matchId = matchId;
        this.status = Status.WAITING;
        this.players = new ConcurrentHashMap<>();
        this.chatHistory = new CopyOnWriteArrayList<>();
    }

    public String getMatchId() { return matchId; }

    public Status getStatus() { return status; }
    public void setStatus(Status status) { this.status = status; }

    public ConcurrentHashMap<String, PlayerState> getPlayers() { return players; }

    public List<ChatMessage> getChatHistory() { return chatHistory; }

    public long getStartTime() { return startTime; }
    public long getEndTime() { return endTime; }

    public boolean canJoin() {
        return players.size() < MAX_PLAYERS;
    }

    public boolean addPlayer(PlayerState player) {
        if (!canJoin()) {
            return false;
        }
        players.put(player.getPlayerId(), player);
        return true;
    }

    public void removePlayer(String playerId) {
        players.remove(playerId);
    }

    public PlayerState getPlayer(String playerId) {
        return players.get(playerId);
    }

    public int getPlayerCount() {
        return players.size();
    }

    public boolean allPlayersReady() {
        if (players.isEmpty()) return false;
        return players.values().stream().allMatch(PlayerState::isReady);
    }

    public boolean anyPlayerReady() {
        return players.values().stream().anyMatch(PlayerState::isReady);
    }

    public void startMatch() {
        this.status = Status.IN_PROGRESS;
        this.startTime = System.currentTimeMillis();
        this.endTime = startTime + (MATCH_DURATION_SECONDS * 1000L);
        // Reset all players to alive state
        players.values().forEach(p -> {
            p.setAlive(true);
            p.setHealth(p.getMaxHealth());
        });
    }

    public int getRemainingTimeSeconds() {
        if (status != Status.IN_PROGRESS) {
            return MATCH_DURATION_SECONDS;
        }
        long remaining = (endTime - System.currentTimeMillis()) / 1000;
        return Math.max(0, (int) remaining);
    }

    public boolean isTimeUp() {
        return status == Status.IN_PROGRESS && System.currentTimeMillis() >= endTime;
    }

    public void endMatch() {
        this.status = Status.FINISHED;
        // Next round should require players to ready up again.
        players.values().forEach(p -> p.setReady(false));
    }

    public void addChatMessage(ChatMessage message) {
        chatHistory.add(message);
        // Keep only last 100 messages
        while (chatHistory.size() > 100) {
            chatHistory.remove(0);
        }
    }

    public List<PlayerState> getScoreboard() {
        return players.values().stream()
                .sorted((a, b) -> Integer.compare(b.getScore(), a.getScore()))
                .collect(Collectors.toList());
    }
}
