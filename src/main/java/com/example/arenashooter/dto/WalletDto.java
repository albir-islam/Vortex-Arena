package com.example.arenashooter.dto;

public class WalletDto {
    private Long userId;
    private int coins;
    private int gems;

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public int getCoins() { return coins; }
    public void setCoins(int coins) { this.coins = coins; }

    public int getGems() { return gems; }
    public void setGems(int gems) { this.gems = gems; }
}
