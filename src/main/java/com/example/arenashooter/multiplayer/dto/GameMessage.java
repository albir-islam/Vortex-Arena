package com.example.arenashooter.multiplayer.dto;

/**
 * Base class for all WebSocket messages.
 */
public class GameMessage {
    private String type;
    private String senderId;
    private String matchId;
    private Object payload;

    public GameMessage() {}

    public GameMessage(String type) {
        this.type = type;
    }

    public String getType() { return type; }
    public void setType(String type) { this.type = type; }

    public String getSenderId() { return senderId; }
    public void setSenderId(String senderId) { this.senderId = senderId; }

    public String getMatchId() { return matchId; }
    public void setMatchId(String matchId) { this.matchId = matchId; }

    public Object getPayload() { return payload; }
    public void setPayload(Object payload) { this.payload = payload; }
}
