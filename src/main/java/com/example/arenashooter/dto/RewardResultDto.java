package com.example.arenashooter.dto;

public class RewardResultDto {
    private Long userId;
    private String matchId;
    private int coinsEarned;
    private int gemsEarned;
    private String reason;
    private int totalCoins;
    private int totalGems;
    private boolean alreadyRewarded;

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public String getMatchId() { return matchId; }
    public void setMatchId(String matchId) { this.matchId = matchId; }

    public int getCoinsEarned() { return coinsEarned; }
    public void setCoinsEarned(int coinsEarned) { this.coinsEarned = coinsEarned; }

    public int getGemsEarned() { return gemsEarned; }
    public void setGemsEarned(int gemsEarned) { this.gemsEarned = gemsEarned; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    public int getTotalCoins() { return totalCoins; }
    public void setTotalCoins(int totalCoins) { this.totalCoins = totalCoins; }

    public int getTotalGems() { return totalGems; }
    public void setTotalGems(int totalGems) { this.totalGems = totalGems; }

    public boolean isAlreadyRewarded() { return alreadyRewarded; }
    public void setAlreadyRewarded(boolean alreadyRewarded) { this.alreadyRewarded = alreadyRewarded; }
}
