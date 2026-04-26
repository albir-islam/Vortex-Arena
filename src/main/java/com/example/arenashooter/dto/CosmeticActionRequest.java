package com.example.arenashooter.dto;

public class CosmeticActionRequest {
    private Long userId;
    private Long cosmeticId;

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public Long getCosmeticId() { return cosmeticId; }
    public void setCosmeticId(Long cosmeticId) { this.cosmeticId = cosmeticId; }
}
