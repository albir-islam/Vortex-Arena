package com.example.arenashooter.dto;

import java.util.List;

public class SeasonLeaderboardDto {
    private Long seasonId;
    private String seasonName;
    private boolean active;
    private List<SeasonRankingEntryDto> rankings;

    public Long getSeasonId() { return seasonId; }
    public void setSeasonId(Long seasonId) { this.seasonId = seasonId; }

    public String getSeasonName() { return seasonName; }
    public void setSeasonName(String seasonName) { this.seasonName = seasonName; }

    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }

    public List<SeasonRankingEntryDto> getRankings() { return rankings; }
    public void setRankings(List<SeasonRankingEntryDto> rankings) { this.rankings = rankings; }

    public static class SeasonRankingEntryDto {
        private Long userId;
        private String username;
        private int eloSnapshot;
        private int rankPosition;

        public Long getUserId() { return userId; }
        public void setUserId(Long userId) { this.userId = userId; }

        public String getUsername() { return username; }
        public void setUsername(String username) { this.username = username; }

        public int getEloSnapshot() { return eloSnapshot; }
        public void setEloSnapshot(int eloSnapshot) { this.eloSnapshot = eloSnapshot; }

        public int getRankPosition() { return rankPosition; }
        public void setRankPosition(int rankPosition) { this.rankPosition = rankPosition; }
    }
}
