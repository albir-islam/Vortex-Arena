package com.example.arenashooter.multiplayer.handler;

import com.example.arenashooter.multiplayer.dto.MessageTypes;
import com.example.arenashooter.multiplayer.model.MatchState;
import com.example.arenashooter.multiplayer.model.PlayerState;
import com.example.arenashooter.multiplayer.service.MatchService;
import com.example.arenashooter.service.MatchEndService;
import com.example.arenashooter.service.ReplayService;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.lang.NonNull;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * WebSocket handler for multiplayer game communication.
 */
@Component
public class MultiplayerWebSocketHandler extends TextWebSocketHandler {

    private final MatchService matchService;
    private final MatchEndService matchEndService;
    private final ReplayService replayService;
    private final ObjectMapper mapper = new ObjectMapper();
    
    // session -> playerId
    private final ConcurrentHashMap<WebSocketSession, String> sessionPlayerMap = new ConcurrentHashMap<>();
    // playerId -> session
    private final ConcurrentHashMap<String, WebSocketSession> playerSessionMap = new ConcurrentHashMap<>();
    // Spectator sessions: session -> target playerId they're watching
    private final ConcurrentHashMap<WebSocketSession, String> spectatorSessions = new ConcurrentHashMap<>();

    public MultiplayerWebSocketHandler(@Qualifier("multiplayerMatchService") MatchService matchService,
                                       MatchEndService matchEndService,
                                       ReplayService replayService) {
        this.matchService = matchService;
        this.matchEndService = matchEndService;
        this.replayService = replayService;
    }

    @Override
    public void afterConnectionEstablished(@NonNull WebSocketSession session) {
        System.out.println("WebSocket connection established: " + session.getId());
    }

    @Override
    protected void handleTextMessage(@NonNull WebSocketSession session, @NonNull TextMessage message) throws Exception {
        try {
            Map<String, Object> data = mapper.readValue(message.getPayload(), 
                new TypeReference<Map<String, Object>>() {});
            
            String type = (String) data.get("type");
            String senderId = (String) data.get("senderId");
            @SuppressWarnings("unchecked")
            Map<String, Object> payload = (Map<String, Object>) data.getOrDefault("payload", new HashMap<>());

            if (type == null) return;

            switch (type) {
                case MessageTypes.JOIN -> handleJoin(session, senderId, payload);
                case MessageTypes.LEAVE -> handleLeave(session, senderId);
                case MessageTypes.READY -> handleReady(senderId, payload);
                case MessageTypes.MOVE -> handleMove(senderId, payload);
                case MessageTypes.SHOOT -> handleShoot(senderId, payload);
                case MessageTypes.HIT_PLAYER -> handleHitPlayer(senderId, payload);
                case MessageTypes.ZOMBIE_KILL -> handleZombieKill(senderId);
                case MessageTypes.RESPAWN -> handleRespawn(senderId);
                case MessageTypes.CHAT -> handleChat(senderId, payload);
                case MessageTypes.SPECTATE -> handleSpectate(session, senderId, payload);
                case MessageTypes.SPECTATE_SWITCH -> handleSpectateSwitch(session, payload);
                default -> System.out.println("Unknown message type: " + type);
            }
        } catch (Exception e) {
            System.err.println("Error handling message: " + e.getMessage());
        }
    }

    @Override
    public void afterConnectionClosed(@NonNull WebSocketSession session, @NonNull CloseStatus status) {
        // Remove spectator if applicable
        spectatorSessions.remove(session);

        String playerId = sessionPlayerMap.remove(session);
        if (playerId != null) {
            playerSessionMap.remove(playerId);
            MatchState match = matchService.leaveMatch(playerId);
            if (match != null) {
                broadcastToMatch(match.getMatchId(), createPlayerLeftMessage(playerId));
                broadcastLobbyState(match);
            }
            System.out.println("Player disconnected: " + playerId);
        }
    }

    // ==================== Message Handlers ====================

    private void handleJoin(WebSocketSession session, String playerId, Map<String, Object> payload) throws Exception {
        String username = (String) payload.getOrDefault("username", playerId);

        // Store session mapping (handle reconnects: keep latest session)
        registerPlayerSession(session, playerId);

        // Clean up any ghost players before building the join response roster.
        pruneStalePlayers();
        
        // Join match
        MatchState match = matchService.joinMatch(playerId, username);
        if (match == null) {
            sendError(session, "Failed to join match");
            return;
        }

        // Send join response to the joining player
        sendJoinResponse(session, match, playerId);

        // Broadcast to all players in match that someone joined
        broadcastToMatch(match.getMatchId(), createPlayerJoinedMessage(match.getPlayer(playerId)));

        // Broadcast full lobby snapshot after join for reliable state sync
        broadcastLobbyState(match);

        // If this is a reconnect and the player was already READY, ensure everyone sees it.
        PlayerState joinedPlayer = match.getPlayer(playerId);
        if (joinedPlayer != null && joinedPlayer.isReady()) {
            broadcastToMatch(match.getMatchId(), createPlayerReadyMessage(playerId, true));
        }

        // If match is already in progress, send current state
        if (match.getStatus() == MatchState.Status.IN_PROGRESS) {
            sendStateUpdate(session, match);
        }
    }

    private void handleLeave(WebSocketSession session, String playerId) {
        MatchState match = matchService.leaveMatch(playerId);
        if (match != null) {
            broadcastToMatch(match.getMatchId(), createPlayerLeftMessage(playerId));
            broadcastLobbyState(match);
        }
        sessionPlayerMap.remove(session);
        playerSessionMap.remove(playerId);
    }

    private void handleReady(String playerId, Map<String, Object> payload) throws Exception {
        // Clean up ghost players so READY/start logic isn't blocked by stale entries.
        pruneStalePlayers();

        boolean ready = parseBoolean(payload.get("ready"), true);
        matchService.setPlayerReady(playerId, ready);

        MatchState match = matchService.getMatchForPlayer(playerId);
        if (match == null) return;

        // Broadcast ready status
        broadcastToMatch(match.getMatchId(), createPlayerReadyMessage(playerId, ready));

        // Broadcast full lobby snapshot after ready change
        broadcastLobbyState(match);

        // Check if match should start
        if (matchService.checkAndStartMatch(match.getMatchId())) {
            broadcastToMatch(match.getMatchId(), createMatchStartMessage(match));
            broadcastLobbyState(match);
        }
    }

    private void handleMove(String playerId, Map<String, Object> payload) {
        double x = ((Number) payload.getOrDefault("x", 0)).doubleValue();
        double y = ((Number) payload.getOrDefault("y", 0)).doubleValue();
        double rotation = ((Number) payload.getOrDefault("rotation", 0)).doubleValue();
        
        matchService.updatePlayerPosition(playerId, x, y, rotation);

        // Broadcast movement to other players
        MatchState match = matchService.getMatchForPlayer(playerId);
        if (match != null) {
            broadcastToMatchExcept(match.getMatchId(), playerId, createPlayerMovedMessage(playerId, x, y, rotation));
        }
    }

    private void handleShoot(String playerId, Map<String, Object> payload) {
        MatchState match = matchService.getMatchForPlayer(playerId);
        if (match == null) return;

        double x = ((Number) payload.getOrDefault("x", 0)).doubleValue();
        double y = ((Number) payload.getOrDefault("y", 0)).doubleValue();
        double direction = ((Number) payload.getOrDefault("direction", 0)).doubleValue();

        // Broadcast shot to all players
        broadcastToMatchExcept(match.getMatchId(), playerId, createPlayerShotMessage(playerId, x, y, direction));

        // Replay: record shoot event
        recordReplayEvent(match.getMatchId(), playerId, "SHOOT",
                String.format("{\"x\":%.2f,\"y\":%.2f,\"direction\":%.2f}", x, y, direction));
    }

    private void handleHitPlayer(String attackerId, Map<String, Object> payload) {
        String targetId = (String) payload.get("targetId");
        int damage = ((Number) payload.getOrDefault("damage", 10)).intValue();

        PlayerState killedPlayer = matchService.handlePlayerHit(attackerId, targetId, damage);
        
        MatchState match = matchService.getMatchForPlayer(attackerId);
        if (match == null) return;

        // Broadcast damage
        broadcastToMatch(match.getMatchId(), createPlayerDamagedMessage(targetId, damage, 
            match.getPlayer(targetId) != null ? match.getPlayer(targetId).getHealth() : 0));

        // Replay: record hit event
        recordReplayEvent(match.getMatchId(), attackerId, "HIT",
                String.format("{\"targetId\":\"%s\",\"damage\":%d}", targetId, damage));

        // If player died, broadcast death
        if (killedPlayer != null) {
            broadcastToMatch(match.getMatchId(), createPlayerKilledMessage(attackerId, targetId));
            broadcastToMatch(match.getMatchId(), createScoreboardMessage(match));

            // Replay: record kill event
            recordReplayEvent(match.getMatchId(), attackerId, "KILL",
                    String.format("{\"victimId\":\"%s\"}", targetId));
        }
    }

    private void handleZombieKill(String playerId) {
        matchService.handleZombieKill(playerId);
        
        MatchState match = matchService.getMatchForPlayer(playerId);
        if (match != null) {
            broadcastToMatch(match.getMatchId(), createScoreboardMessage(match));
        }
    }

    private void handleRespawn(String playerId) throws Exception {
        double[] spawn = matchService.respawnPlayer(playerId);
        if (spawn == null) return;

        MatchState match = matchService.getMatchForPlayer(playerId);
        if (match == null) return;

        // Broadcast respawn
        broadcastToMatch(match.getMatchId(), createPlayerRespawnedMessage(playerId, spawn[0], spawn[1]));

        // Replay: record respawn event
        recordReplayEvent(match.getMatchId(), playerId, "RESPAWN",
                String.format("{\"x\":%.2f,\"y\":%.2f}", spawn[0], spawn[1]));
    }

    private void handleChat(String senderId, Map<String, Object> payload) {
        String message = (String) payload.getOrDefault("message", "");
        if (message.isBlank()) return;

        matchService.addChatMessage(senderId, message);

        MatchState match = matchService.getMatchForPlayer(senderId);
        if (match != null) {
            PlayerState player = match.getPlayer(senderId);
            if (player != null) {
                broadcastToMatch(match.getMatchId(), 
                    createChatMessage(senderId, player.getUsername(), message));
            }
        }
    }

    // ==================== Spectator Handlers ====================

    private void handleSpectate(WebSocketSession session, String spectatorId, Map<String, Object> payload) throws Exception {
        String matchId = (String) payload.getOrDefault("matchId", "GLOBAL");
        MatchState match = matchService.getMatch(matchId);
        if (match == null) {
            sendError(session, "Match not found");
            return;
        }

        // Register as spectator (not a player)
        spectatorSessions.put(session, matchId);

        // Send current full state
        Map<String, Object> resp = new HashMap<>();
        resp.put("type", MessageTypes.SPECTATE_RESPONSE);
        resp.put("success", true);
        resp.put("matchId", matchId);
        resp.put("matchStatus", match.getStatus().toString());
        resp.put("players", getPlayersPayload(match));
        resp.put("scoreboard", getScoreboardPayload(match));
        resp.put("remainingTime", match.getRemainingTimeSeconds());
        sendMessage(session, resp);
    }

    private void handleSpectateSwitch(WebSocketSession session, Map<String, Object> payload) throws Exception {
        String targetId = (String) payload.get("targetPlayerId");
        if (targetId != null) {
            // Just acknowledge; the client controls camera locally
            Map<String, Object> msg = new HashMap<>();
            msg.put("type", MessageTypes.SPECTATE_SWITCH);
            msg.put("targetPlayerId", targetId);
            sendMessage(session, msg);
        }
    }

    /**
     * Send a state snapshot to all spectators watching the given match.
     */
    private void broadcastToSpectators(String matchId, Map<String, Object> message) {
        String json;
        try {
            json = mapper.writeValueAsString(message);
        } catch (Exception e) {
            return;
        }
        for (Map.Entry<WebSocketSession, String> entry : spectatorSessions.entrySet()) {
            if (matchId.equals(entry.getValue()) && entry.getKey().isOpen()) {
                try {
                    entry.getKey().sendMessage(new TextMessage(Objects.requireNonNull(json)));
                } catch (Exception ignored) {
                    // best-effort
                }
            }
        }
    }

    // ==================== Message Creation ====================

    private Map<String, Object> createPlayerJoinedMessage(PlayerState player) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.PLAYER_JOINED);
        msg.put("playerId", player.getPlayerId());
        msg.put("username", player.getUsername());
        msg.put("x", player.getX());
        msg.put("y", player.getY());
        msg.put("ready", player.isReady());
        return msg;
    }

    private Map<String, Object> createPlayerLeftMessage(String playerId) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.PLAYER_LEFT);
        msg.put("playerId", playerId);
        return msg;
    }

    private Map<String, Object> createPlayerReadyMessage(String playerId, boolean ready) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.PLAYER_READY);
        msg.put("playerId", playerId);
        msg.put("ready", ready);
        return msg;
    }

    private Map<String, Object> createMatchStartMessage(MatchState match) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.MATCH_START);
        msg.put("matchId", match.getMatchId());
        msg.put("duration", match.getRemainingTimeSeconds());
        msg.put("players", getPlayersPayload(match));
        return msg;
    }

    private Map<String, Object> createMatchEndMessage(MatchState match) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.MATCH_END);
        msg.put("matchId", match.getMatchId());
        msg.put("scoreboard", getScoreboardPayload(match));
        return msg;
    }

    private Map<String, Object> createPlayerMovedMessage(String playerId, double x, double y, double rotation) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.PLAYER_MOVED);
        msg.put("playerId", playerId);
        msg.put("x", x);
        msg.put("y", y);
        msg.put("rotation", rotation);
        return msg;
    }

    private Map<String, Object> createPlayerShotMessage(String playerId, double x, double y, double direction) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.PLAYER_SHOT);
        msg.put("playerId", playerId);
        msg.put("x", x);
        msg.put("y", y);
        msg.put("direction", direction);
        return msg;
    }

    private Map<String, Object> createPlayerDamagedMessage(String targetId, int damage, int remainingHealth) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.PLAYER_DAMAGED);
        msg.put("playerId", targetId);
        msg.put("damage", damage);
        msg.put("health", remainingHealth);
        return msg;
    }

    private Map<String, Object> createPlayerKilledMessage(String killerId, String victimId) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.PLAYER_KILLED);
        msg.put("killerId", killerId);
        msg.put("victimId", victimId);
        return msg;
    }

    private Map<String, Object> createPlayerRespawnedMessage(String playerId, double x, double y) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.PLAYER_RESPAWNED);
        msg.put("playerId", playerId);
        msg.put("x", x);
        msg.put("y", y);
        return msg;
    }

    private Map<String, Object> createChatMessage(String senderId, String username, String message) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.CHAT_MESSAGE);
        msg.put("senderId", senderId);
        msg.put("username", username);
        msg.put("message", message);
        msg.put("timestamp", System.currentTimeMillis());
        return msg;
    }

    private Map<String, Object> createScoreboardMessage(MatchState match) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.SCOREBOARD);
        msg.put("scoreboard", getScoreboardPayload(match));
        return msg;
    }

    private Map<String, Object> createTimeUpdateMessage(MatchState match) {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.TIME_UPDATE);
        msg.put("remainingTime", match.getRemainingTimeSeconds());
        return msg;
    }

    private List<Map<String, Object>> getPlayersPayload(MatchState match) {
        List<Map<String, Object>> players = new ArrayList<>();
        for (PlayerState p : match.getPlayers().values()) {
            Map<String, Object> pData = new HashMap<>();
            pData.put("playerId", p.getPlayerId());
            pData.put("username", p.getUsername());
            pData.put("x", p.getX());
            pData.put("y", p.getY());
            pData.put("rotation", p.getRotation());
            pData.put("health", p.getHealth());
            pData.put("alive", p.isAlive());
            pData.put("ready", p.isReady());
            players.add(pData);
        }
        return players;
    }

    private Map<String, Object> createLobbyStateMessage(MatchState match) {
        Map<String, Object> msg = new HashMap<>();
        // Reuse STATE_UPDATE so clients can safely ignore/consume it without breaking.
        msg.put("type", MessageTypes.STATE_UPDATE);
        msg.put("matchId", match.getMatchId());
        msg.put("matchStatus", match.getStatus().toString());
        msg.put("players", getPlayersPayload(match));
        msg.put("remainingTime", match.getRemainingTimeSeconds());
        msg.put("scoreboard", getScoreboardPayload(match));
        return msg;
    }

    private void broadcastLobbyState(MatchState match) {
        if (match == null) return;
        broadcastToMatch(match.getMatchId(), createLobbyStateMessage(match));
    }

    private void registerPlayerSession(WebSocketSession session, String playerId) {
        if (session == null || playerId == null) return;

        WebSocketSession oldSession = playerSessionMap.put(playerId, session);
        if (oldSession != null && oldSession != session) {
            sessionPlayerMap.remove(oldSession);
            try {
                if (oldSession.isOpen()) {
                    oldSession.close();
                }
            } catch (Exception ignored) {
                // Best-effort cleanup
            }
        }

        sessionPlayerMap.put(session, playerId);
    }

    private boolean parseBoolean(Object value, boolean defaultValue) {
        if (value == null) return defaultValue;
        if (value instanceof Boolean b) return b;
        if (value instanceof Number n) return n.intValue() != 0;
        if (value instanceof String s) {
            String normalized = s.trim().toLowerCase(Locale.ROOT);
            if (normalized.equals("true") || normalized.equals("1") || normalized.equals("yes") || normalized.equals("y")) return true;
            if (normalized.equals("false") || normalized.equals("0") || normalized.equals("no") || normalized.equals("n")) return false;
        }
        return defaultValue;
    }

    private List<Map<String, Object>> getScoreboardPayload(MatchState match) {
        List<Map<String, Object>> scoreboard = new ArrayList<>();
        for (PlayerState p : match.getScoreboard()) {
            Map<String, Object> pData = new HashMap<>();
            pData.put("playerId", p.getPlayerId());
            pData.put("username", p.getUsername());
            pData.put("score", p.getScore());
            pData.put("playerKills", p.getPlayerKills());
            pData.put("zombieKills", p.getZombieKills());
            pData.put("alive", p.isAlive());
            scoreboard.add(pData);
        }
        return scoreboard;
    }

    // ==================== Utility Methods ====================

    private void sendJoinResponse(WebSocketSession session, MatchState match, String playerId) throws Exception {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.JOIN_RESPONSE);
        msg.put("success", true);
        msg.put("matchId", match.getMatchId());
        msg.put("playerId", playerId);
        msg.put("matchStatus", match.getStatus().toString());
        msg.put("players", getPlayersPayload(match));
        
        if (match.getStatus() == MatchState.Status.IN_PROGRESS) {
            msg.put("remainingTime", match.getRemainingTimeSeconds());
        }
        
        sendMessage(session, msg);
    }

    private void sendError(WebSocketSession session, String error) throws Exception {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.ERROR);
        msg.put("error", error);
        sendMessage(session, msg);
    }

    private void sendStateUpdate(WebSocketSession session, MatchState match) throws Exception {
        Map<String, Object> msg = new HashMap<>();
        msg.put("type", MessageTypes.STATE_UPDATE);
        msg.put("players", getPlayersPayload(match));
        msg.put("remainingTime", match.getRemainingTimeSeconds());
        msg.put("scoreboard", getScoreboardPayload(match));
        sendMessage(session, msg);
    }

    private void sendMessage(WebSocketSession session, Map<String, Object> message) throws Exception {
        if (session != null && session.isOpen()) {
            String json = mapper.writeValueAsString(message);
            session.sendMessage(new TextMessage(Objects.requireNonNull(json, "json")));
        }
    }

    private void broadcastToMatch(String matchId, Map<String, Object> message) {
        MatchState match = matchService.getMatch(matchId);
        if (match == null) return;

        String json;
        try {
            json = mapper.writeValueAsString(message);
        } catch (Exception e) {
            System.err.println("Failed to serialize message: " + e.getMessage());
            return;
        }

        for (PlayerState player : match.getPlayers().values()) {
            WebSocketSession session = playerSessionMap.get(player.getPlayerId());
            if (session != null && session.isOpen()) {
                try {
                    session.sendMessage(new TextMessage(Objects.requireNonNull(json, "json")));
                } catch (Exception e) {
                    System.err.println("Failed to send to " + player.getPlayerId());
                }
            }
        }
    }

    private void broadcastToMatchExcept(String matchId, String exceptPlayerId, Map<String, Object> message) {
        MatchState match = matchService.getMatch(matchId);
        if (match == null) return;

        String json;
        try {
            json = mapper.writeValueAsString(message);
        } catch (Exception e) {
            System.err.println("Failed to serialize message: " + e.getMessage());
            return;
        }

        for (PlayerState player : match.getPlayers().values()) {
            if (player.getPlayerId().equals(exceptPlayerId)) continue;
            
            WebSocketSession session = playerSessionMap.get(player.getPlayerId());
            if (session != null && session.isOpen()) {
                try {
                    session.sendMessage(new TextMessage(Objects.requireNonNull(json, "json")));
                } catch (Exception e) {
                    System.err.println("Failed to send to " + player.getPlayerId());
                }
            }
        }
    }

    // ==================== Scheduled Tasks ====================

    /**
     * Periodic tick to update match timers and check for timeouts.
     */
    @Scheduled(fixedRate = 1000) // Every second
    public void tick() {
        pruneStalePlayers();

        // Check for match timeouts
        List<MatchState> endedMatches = matchService.checkMatchTimeouts();
        for (MatchState match : endedMatches) {
            broadcastToMatch(match.getMatchId(), createMatchEndMessage(match));
            broadcastToSpectators(match.getMatchId(), createMatchEndMessage(match));

            // ── Post-match processing: rewards, ELO, history, achievements ──
            try {
                matchEndService.processMatchEnd(match);
            } catch (Exception e) {
                System.err.println("Error processing match end: " + e.getMessage());
            }
        }

        // Send time updates for active matches (+ spectators)
        for (MatchState match : matchService.getAllMatches()) {
            if (match.getStatus() == MatchState.Status.IN_PROGRESS) {
                broadcastToMatch(match.getMatchId(), createTimeUpdateMessage(match));
                // Also send full state to spectators every tick
                broadcastToSpectators(match.getMatchId(), createLobbyStateMessage(match));
            }
        }
    }

    private void pruneStalePlayers() {
        for (MatchState match : matchService.getAllMatches()) {
            List<String> stalePlayerIds = new ArrayList<>();
            for (PlayerState player : match.getPlayers().values()) {
                WebSocketSession session = playerSessionMap.get(player.getPlayerId());
                if (session == null || !session.isOpen()) {
                    stalePlayerIds.add(player.getPlayerId());
                }
            }

            for (String playerId : stalePlayerIds) {
                playerSessionMap.remove(playerId);
                MatchState updatedMatch = matchService.leaveMatch(playerId);
                if (updatedMatch != null) {
                    broadcastToMatch(updatedMatch.getMatchId(), createPlayerLeftMessage(playerId));
                    broadcastLobbyState(updatedMatch);
                }
            }
        }
    }

    /**
     * Record a replay event, swallowing errors so gameplay isn't affected.
     */
    private void recordReplayEvent(String matchId, String playerId, String eventType, String dataJson) {
        try {
            Long uid = Long.parseLong(playerId);
            replayService.recordEvent(matchId, uid, eventType, dataJson);
        } catch (NumberFormatException ignored) {
            // player id not numeric – skip replay recording
        } catch (Exception e) {
            System.err.println("Replay record error: " + e.getMessage());
        }
    }
}
