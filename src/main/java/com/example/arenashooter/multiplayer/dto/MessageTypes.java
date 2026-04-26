package com.example.arenashooter.multiplayer.dto;

/**
 * Message types for multiplayer communication.
 */
public final class MessageTypes {
    // Client -> Server
    public static final String JOIN = "JOIN";
    public static final String LEAVE = "LEAVE";
    public static final String READY = "READY";
    public static final String MOVE = "MOVE";
    public static final String SHOOT = "SHOOT";
    public static final String HIT_PLAYER = "HIT_PLAYER";
    public static final String ZOMBIE_KILL = "ZOMBIE_KILL";
    public static final String RESPAWN = "RESPAWN";
    public static final String CHAT = "CHAT";

    // Server -> Client
    public static final String PLAYER_JOINED = "PLAYER_JOINED";
    public static final String PLAYER_LEFT = "PLAYER_LEFT";
    public static final String PLAYER_READY = "PLAYER_READY";
    public static final String MATCH_START = "MATCH_START";
    public static final String MATCH_END = "MATCH_END";
    public static final String STATE_UPDATE = "STATE_UPDATE";
    public static final String PLAYER_MOVED = "PLAYER_MOVED";
    public static final String PLAYER_SHOT = "PLAYER_SHOT";
    public static final String PLAYER_DAMAGED = "PLAYER_DAMAGED";
    public static final String PLAYER_DIED = "PLAYER_DIED";
    public static final String PLAYER_RESPAWNED = "PLAYER_RESPAWNED";
    public static final String PLAYER_KILLED = "PLAYER_KILLED";
    public static final String CHAT_MESSAGE = "CHAT_MESSAGE";
    public static final String SCOREBOARD = "SCOREBOARD";
    public static final String TIME_UPDATE = "TIME_UPDATE";
    public static final String JOIN_RESPONSE = "JOIN_RESPONSE";
    public static final String ERROR = "ERROR";

    // Spectator mode
    public static final String SPECTATE = "SPECTATE";          // Client -> Server: join as spectator
    public static final String SPECTATE_RESPONSE = "SPECTATE_RESPONSE"; // Server -> Client
    public static final String SPECTATE_UPDATE = "SPECTATE_UPDATE";     // Server -> Client: full state for spectators
    public static final String SPECTATE_SWITCH = "SPECTATE_SWITCH";     // Client -> Server: switch camera target

    // Post-match
    public static final String MATCH_REWARDS = "MATCH_REWARDS"; // Server -> Client: reward summary

    private MessageTypes() {}
}
