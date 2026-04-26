package com.example.arenashooter.multiplayer.model;

/**
 * Represents a chat message in multiplayer.
 */
public class ChatMessage {
    private String senderId;
    private String senderName;
    private String message;
    private long timestamp;

    public ChatMessage() {
        this.timestamp = System.currentTimeMillis();
    }

    public ChatMessage(String senderId, String senderName, String message) {
        this();
        this.senderId = senderId;
        this.senderName = senderName;
        this.message = message;
    }

    public String getSenderId() { return senderId; }
    public void setSenderId(String senderId) { this.senderId = senderId; }

    public String getSenderName() { return senderName; }
    public void setSenderName(String senderName) { this.senderName = senderName; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public long getTimestamp() { return timestamp; }
    public void setTimestamp(long timestamp) { this.timestamp = timestamp; }
}
