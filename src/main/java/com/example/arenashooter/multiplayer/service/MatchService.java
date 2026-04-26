package com.example.arenashooter.multiplayer.service;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Service;

import com.example.arenashooter.multiplayer.model.ChatMessage;
import com.example.arenashooter.multiplayer.model.MatchState;
import com.example.arenashooter.multiplayer.model.PlayerState;

/**
 * Service for managing multiplayer matches.
 */
@Service("multiplayerMatchService")
public class MatchService {

    private static final String GLOBAL_MATCH_ID = "GLOBAL";
    private static final int MIN_PLAYERS_TO_START = 1;
    
    // matchId -> MatchState (we intentionally keep a single global lobby/match)
    private final ConcurrentHashMap<String, MatchState> matches = new ConcurrentHashMap<>();
    
    // playerId -> matchId (for quick lookup)
    private final ConcurrentHashMap<String, String> playerMatchMapping = new ConcurrentHashMap<>();

    // Points configuration
    private static final int ZOMBIE_KILL_POINTS = 100;
    private static final int PLAYER_KILL_POINTS = 200; // 2x zombie kill

    public MatchService() {
        // Ensure the global lobby is present from startup.
        matches.put(GLOBAL_MATCH_ID, new MatchState(GLOBAL_MATCH_ID));
    }

    private MatchState getOrCreateGlobalMatch() {
        return matches.computeIfAbsent(GLOBAL_MATCH_ID, MatchState::new);
    }

    /**
     * Find or create a match for a player to join.
     *
     * This server uses a single shared lobby/match instance across all connections.
     */
    public MatchState findOrCreateMatch() {
        return getOrCreateGlobalMatch();
    }

    /**
     * Add a player to a match.
     */
    public synchronized MatchState joinMatch(String playerId, String username) {
        MatchState match = findOrCreateMatch();

        // Reconnect / re-join: keep existing player state and mapping
        PlayerState existingPlayer = match.getPlayer(playerId);
        if (existingPlayer != null) {
            existingPlayer.setUsername(username);
            playerMatchMapping.put(playerId, match.getMatchId());
            return match;
        }

        PlayerState playerState = new PlayerState(playerId, username);

        // Set random spawn position
        double[] spawn = getRandomSpawnPoint();
        playerState.setX(spawn[0]);
        playerState.setY(spawn[1]);

        if (match.addPlayer(playerState)) {
            playerMatchMapping.put(playerId, match.getMatchId());
            System.out.println("Player " + username + " joined match " + match.getMatchId() +
                    " (Total: " + match.getPlayerCount() + " players)");
            return match;
        }

        return null;
    }

    /**
     * Remove a player from their match.
     */
    public MatchState leaveMatch(String playerId) {
        String matchId = playerMatchMapping.remove(playerId);
        if (matchId == null) return null;

        MatchState match = matches.get(matchId);
        if (match != null) {
            match.removePlayer(playerId);
            System.out.println("Player " + playerId + " left match " + matchId);

            // If lobby becomes empty, reset it back to WAITING while keeping the same matchId.
            if (match.getPlayerCount() == 0 && GLOBAL_MATCH_ID.equals(matchId)) {
                matches.put(GLOBAL_MATCH_ID, new MatchState(GLOBAL_MATCH_ID));
                match = matches.get(GLOBAL_MATCH_ID);
                System.out.println("Global lobby reset (empty)");
            }
        }
        return match;
    }

    /**
     * Get match by ID.
     */
    public MatchState getMatch(String matchId) {
        return matches.get(matchId);
    }

    /**
     * Get match for a player.
     */
    public MatchState getMatchForPlayer(String playerId) {
        String matchId = playerMatchMapping.get(playerId);
        if (matchId == null) return null;
        return matches.get(matchId);
    }

    /**
     * Set player ready status.
     */
    public boolean setPlayerReady(String playerId, boolean ready) {
        MatchState match = getMatchForPlayer(playerId);
        if (match == null) return false;

        PlayerState player = match.getPlayer(playerId);
        if (player == null) return false;

        player.setReady(ready);
        return true;
    }

    /**
     * Check and start match if conditions are met.
     * Match starts when the only player is ready, or when all players are ready.
     */
    public boolean checkAndStartMatch(String matchId) {
        MatchState match = matches.get(matchId);
        if (match == null) {
            return false;
        }

        // With a single global lobby, allow starting a new round after FINISHED.
        if (match.getStatus() == MatchState.Status.FINISHED) {
            match.setStatus(MatchState.Status.WAITING);
        }

        if (match.getStatus() != MatchState.Status.WAITING) {
            return false;
        }

        int playerCount = match.getPlayerCount();
        boolean shouldStart = playerCount >= MIN_PLAYERS_TO_START && match.allPlayersReady();

        if (shouldStart) {
            match.startMatch();
            System.out.println("Match " + matchId + " started with " + match.getPlayerCount() + " players");
            return true;
        }
        return false;
    }

    /**
     * Update player position.
     */
    public void updatePlayerPosition(String playerId, double x, double y, double rotation) {
        MatchState match = getMatchForPlayer(playerId);
        if (match == null) return;

        PlayerState player = match.getPlayer(playerId);
        if (player != null && player.isAlive()) {
            player.setX(x);
            player.setY(y);
            player.setRotation(rotation);
        }
    }

    /**
     * Handle player hitting another player.
     * Returns the killed player if they died, null otherwise.
     */
    public PlayerState handlePlayerHit(String attackerId, String targetId, int damage) {
        MatchState match = getMatchForPlayer(attackerId);
        if (match == null || match.getStatus() != MatchState.Status.IN_PROGRESS) return null;

        PlayerState attacker = match.getPlayer(attackerId);
        PlayerState target = match.getPlayer(targetId);
        
        if (attacker == null || target == null || !target.isAlive()) return null;

        target.takeDamage(damage);
        
        if (!target.isAlive()) {
            // Target died - award points to attacker
            attacker.addPlayerKill();
            attacker.addScore(PLAYER_KILL_POINTS);
            System.out.println(attacker.getUsername() + " killed " + target.getUsername());
            return target;
        }
        
        return null;
    }

    /**
     * Handle zombie kill.
     */
    public void handleZombieKill(String playerId) {
        MatchState match = getMatchForPlayer(playerId);
        if (match == null) return;

        PlayerState player = match.getPlayer(playerId);
        if (player != null) {
            player.addZombieKill();
            player.addScore(ZOMBIE_KILL_POINTS);
        }
    }

    /**
     * Handle player respawn.
     */
    public double[] respawnPlayer(String playerId) {
        MatchState match = getMatchForPlayer(playerId);
        if (match == null || match.getStatus() != MatchState.Status.IN_PROGRESS) return null;

        PlayerState player = match.getPlayer(playerId);
        if (player == null) return null;

        double[] spawn = getRandomSpawnPoint();
        player.respawn(spawn[0], spawn[1]);
        return spawn;
    }

    /**
     * Add chat message.
     */
    public void addChatMessage(String playerId, String message) {
        MatchState match = getMatchForPlayer(playerId);
        if (match == null) return;

        PlayerState player = match.getPlayer(playerId);
        if (player != null) {
            ChatMessage chatMsg = new ChatMessage(playerId, player.getUsername(), message);
            match.addChatMessage(chatMsg);
        }
    }

    /**
     * Check if any matches have timed out.
     */
    public List<MatchState> checkMatchTimeouts() {
        List<MatchState> endedMatches = new ArrayList<>();
        for (MatchState match : matches.values()) {
            if (match.isTimeUp()) {
                match.endMatch();
                endedMatches.add(match);
                System.out.println("Match " + match.getMatchId() + " ended (time up)");
            }
        }
        return endedMatches;
    }

    /**
     * Get all active matches.
     */
    public Collection<MatchState> getAllMatches() {
        return matches.values();
    }

    /**
     * Generate random spawn point within map bounds.
     */
    private double[] getRandomSpawnPoint() {
        // Map bounds (adjust based on your actual map)
        double minX = 200;
        double maxX = 1600;
        double minY = 200;
        double maxY = 900;
        
        Random rand = new Random();
        double x = minX + rand.nextDouble() * (maxX - minX);
        double y = minY + rand.nextDouble() * (maxY - minY);
        
        return new double[]{x, y};
    }
}
