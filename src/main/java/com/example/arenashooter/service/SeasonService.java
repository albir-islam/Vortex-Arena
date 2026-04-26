package com.example.arenashooter.service;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.example.arenashooter.dto.SeasonLeaderboardDto;
import com.example.arenashooter.entity.PlayerStats;
import com.example.arenashooter.entity.Season;
import com.example.arenashooter.entity.SeasonRanking;
import com.example.arenashooter.repository.PlayerStatsRepository;
import com.example.arenashooter.repository.SeasonRankingRepository;
import com.example.arenashooter.repository.SeasonRepository;
import com.example.arenashooter.repository.UserRepository;

/**
 * Seasonal leaderboard management.
 * At the end of each season, ELO snapshots are frozen into season_rankings
 * so players can see historical standings.
 */
@Service
public class SeasonService {

    private final SeasonRepository seasonRepo;
    private final SeasonRankingRepository rankingRepo;
    private final PlayerStatsRepository statsRepo;
    private final UserRepository userRepo;

    public SeasonService(SeasonRepository seasonRepo,
                         SeasonRankingRepository rankingRepo,
                         PlayerStatsRepository statsRepo,
                         UserRepository userRepo) {
        this.seasonRepo = seasonRepo;
        this.rankingRepo = rankingRepo;
        this.statsRepo = statsRepo;
        this.userRepo = userRepo;
    }

    /**
     * Get the current active season.
     */
    public Optional<Season> getCurrentSeason() {
        return seasonRepo.findByActiveTrue();
    }

    /**
     * Get the leaderboard for a specific season.
     */
    public SeasonLeaderboardDto getSeasonLeaderboard(Long seasonId) {
        Season season = seasonRepo.findById(seasonId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Season not found"));

        List<SeasonRanking> rankings = rankingRepo.findBySeasonIdOrderByEloSnapshotDesc(seasonId);

        SeasonLeaderboardDto dto = new SeasonLeaderboardDto();
        dto.setSeasonId(season.getSeasonId());
        dto.setSeasonName(season.getName());
        dto.setActive(season.isActive());
        dto.setRankings(rankings.stream().map(r -> {
            SeasonLeaderboardDto.SeasonRankingEntryDto entry = new SeasonLeaderboardDto.SeasonRankingEntryDto();
            entry.setUserId(r.getUserId());
            entry.setEloSnapshot(r.getEloSnapshot());
            entry.setRankPosition(r.getRankPosition());
            // Resolve username
            userRepo.findById(r.getUserId()).ifPresent(u -> entry.setUsername(u.getUsername()));
            return entry;
        }).collect(Collectors.toList()));

        return dto;
    }

    /**
     * Snapshot all players' current ELO into season rankings.
     * Typically called at season end or periodically.
     */
    @Transactional
    public void snapshotRankings(Long seasonId) {
        Season season = seasonRepo.findById(seasonId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Season not found"));

        List<PlayerStats> allStats = statsRepo.findAll().stream()
                .sorted((a, b) -> Integer.compare(b.getEloRating(), a.getEloRating()))
                .collect(Collectors.toList());

        int rank = 1;
        for (PlayerStats stats : allStats) {
            Optional<SeasonRanking> existing = rankingRepo.findBySeasonIdAndUserId(seasonId, stats.getUser().getId());
            SeasonRanking sr;
            if (existing.isPresent()) {
                sr = existing.get();
            } else {
                sr = new SeasonRanking();
                sr.setSeasonId(seasonId);
                sr.setUserId(stats.getUser().getId());
            }
            sr.setEloSnapshot(stats.getEloRating());
            sr.setRankPosition(rank++);
            rankingRepo.save(sr);
        }
    }

    /**
     * End the current season, freeze rankings, and optionally start a new one.
     */
    @Transactional
    public Season endSeasonAndStartNew(String newSeasonName,
                                       java.time.LocalDate newStart,
                                       java.time.LocalDate newEnd) {
        Optional<Season> current = seasonRepo.findByActiveTrue();
        if (current.isPresent()) {
            Season old = current.get();
            snapshotRankings(old.getSeasonId());
            old.setActive(false);
            seasonRepo.save(old);
        }

        Season next = new Season();
        next.setName(newSeasonName);
        next.setStartDate(newStart);
        next.setEndDate(newEnd);
        next.setActive(true);
        return seasonRepo.save(next);
    }
}
