package com.example.arenashooter.dto;

import java.time.LocalDateTime;

public class MatchHistoryDto {
    private String matchId;
    private Long playerId;
    private int kills;
    private int deaths;
    private int damage;
    private int placement;
    private String result;
    private LocalDateTime timestamp;

    public String getMatchId() { return matchId; }
    public void setMatchId(String matchId) { this.matchId = matchId; }

    public Long getPlayerId() { return playerId; }
    public void setPlayerId(Long playerId) { this.playerId = playerId; }

    public int getKills() { return kills; }
    public void setKills(int kills) { this.kills = kills; }

    public int getDeaths() { return deaths; }
    public void setDeaths(int deaths) { this.deaths = deaths; }

    public int getDamage() { return damage; }
    public void setDamage(int damage) { this.damage = damage; }

    public int getPlacement() { return placement; }
    public void setPlacement(int placement) { this.placement = placement; }

    public String getResult() { return result; }
    public void setResult(String result) { this.result = result; }

    public LocalDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(LocalDateTime timestamp) { this.timestamp = timestamp; }
}
