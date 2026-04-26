package com.example.arenashooter.dto;

public class MatchRewardRequest {
    private Long userId;
    private String matchId;
    private int kills;
    private boolean won;
    private boolean mvp;
    private int damage;
    private int deaths;
    private int placement;

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public String getMatchId() { return matchId; }
    public void setMatchId(String matchId) { this.matchId = matchId; }

    public int getKills() { return kills; }
    public void setKills(int kills) { this.kills = kills; }

    public boolean isWon() { return won; }
    public void setWon(boolean won) { this.won = won; }

    public boolean isMvp() { return mvp; }
    public void setMvp(boolean mvp) { this.mvp = mvp; }

    public int getDamage() { return damage; }
    public void setDamage(int damage) { this.damage = damage; }

    public int getDeaths() { return deaths; }
    public void setDeaths(int deaths) { this.deaths = deaths; }

    public int getPlacement() { return placement; }
    public void setPlacement(int placement) { this.placement = placement; }
}
