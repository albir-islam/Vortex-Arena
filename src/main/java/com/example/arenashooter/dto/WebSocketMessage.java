package com.example.arenashooter.dto;

public class WebSocketMessage {
    private String type; // LOGIN, MOVE, SHOOT, HIT, DEATH, UPDATE
    private String senderId;
    private Object payload; // Flexible payload (Map or specific object)

    // Standard getters/setters
    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public String getSenderId() {
        return senderId;
    }

    public void setSenderId(String senderId) {
        this.senderId = senderId;
    }

    public Object getPayload() {
        return payload;
    }

    public void setPayload(Object payload) {
        this.payload = payload;
    }
}
