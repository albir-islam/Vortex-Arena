package com.example.arenashooter.dto;

public class KillUpdateRequest {
    private Long userId;
    private int scoreGain;

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public int getScoreGain() {
        return scoreGain;
    }

    public void setScoreGain(int scoreGain) {
        this.scoreGain = scoreGain;
    }
}
