package com.example.arenashooter.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "season_rankings",
       uniqueConstraints = @UniqueConstraint(columnNames = {"season_id", "user_id"}))
public class SeasonRanking {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "season_id", nullable = false)
    private Long seasonId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "elo_snapshot", nullable = false)
    private int eloSnapshot = 1000;

    @Column(name = "rank_position", nullable = false)
    private int rankPosition = 0;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getSeasonId() { return seasonId; }
    public void setSeasonId(Long seasonId) { this.seasonId = seasonId; }

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public int getEloSnapshot() { return eloSnapshot; }
    public void setEloSnapshot(int eloSnapshot) { this.eloSnapshot = eloSnapshot; }

    public int getRankPosition() { return rankPosition; }
    public void setRankPosition(int rankPosition) { this.rankPosition = rankPosition; }
}
