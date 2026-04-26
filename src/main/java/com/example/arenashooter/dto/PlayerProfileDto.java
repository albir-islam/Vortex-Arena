package com.example.arenashooter.dto;

public class PlayerProfileDto {
    private Long userId;
    private String username;
    private String currentDress;
    private InventoryDto inventory;
    private PlayerStatsDto stats;

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getCurrentDress() {
        return currentDress;
    }

    public void setCurrentDress(String currentDress) {
        this.currentDress = currentDress;
    }

    public InventoryDto getInventory() {
        return inventory;
    }

    public void setInventory(InventoryDto inventory) {
        this.inventory = inventory;
    }

    public PlayerStatsDto getStats() {
        return stats;
    }

    public void setStats(PlayerStatsDto stats) {
        this.stats = stats;
    }
}
