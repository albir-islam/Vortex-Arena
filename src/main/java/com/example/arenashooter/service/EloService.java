package com.example.arenashooter.service;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.example.arenashooter.dto.EloDto;
import com.example.arenashooter.entity.PlayerStats;
import com.example.arenashooter.entity.User;
import com.example.arenashooter.repository.PlayerStatsRepository;
import com.example.arenashooter.repository.UserRepository;

/**
 * ELO rating calculations and tier management.
 * <p>
 * Formula:  NewELO = OldELO + K × (Result − Expected)
 * <ul>
 *   <li>K = 32 (standard)</li>
 *   <li>Result  = 1.0 for win, 0.0 for loss</li>
 *   <li>Expected = 1 / (1 + 10^((opponentELO − playerELO) / 400))</li>
 * </ul>
 *
 * Tiers:
 * <pre>
 *   BRONZE   &lt; 1000
 *   SILVER   1000–1199
 *   GOLD     1200–1399
 *   PLATINUM 1400–1599
 *   DIAMOND  1600–1799
 *   MASTER   ≥ 1800
 * </pre>
 */
@Service
public class EloService {

    private static final int K_FACTOR = 32;

    private final PlayerStatsRepository statsRepo;
    private final UserRepository userRepo;

    public EloService(PlayerStatsRepository statsRepo, UserRepository userRepo) {
        this.statsRepo = statsRepo;
        this.userRepo = userRepo;
    }

    /**
     * Recalculate ELO for a player after a match.
     *
     * @param userId      the player whose rating is updated
     * @param opponentElo average ELO of opponent(s) in the match
     * @param won         whether this player won
     * @return updated EloDto
     */
    @Transactional
    public EloDto calculateAndUpdate(Long userId, int opponentElo, boolean won) {
        PlayerStats stats = statsRepo.findByUserId(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Stats not found"));

        int oldElo = stats.getEloRating();
        double expected = 1.0 / (1.0 + Math.pow(10, (opponentElo - oldElo) / 400.0));
        double result = won ? 1.0 : 0.0;
        int newElo = (int) Math.round(oldElo + K_FACTOR * (result - expected));
        // Floor at 0
        newElo = Math.max(0, newElo);

        stats.setEloRating(newElo);
        stats.setTier(getTier(newElo));
        stats.setMatchesPlayed(stats.getMatchesPlayed() + 1);
        if (won) {
            stats.setMatchesWon(stats.getMatchesWon() + 1);
        }
        statsRepo.save(stats);

        return toDto(stats);
    }

    /**
     * Convenience: update aggregate damage/deaths after a match.
     */
    @Transactional
    public void recordMatchStats(Long userId, int kills, int deaths, int damage) {
        PlayerStats stats = statsRepo.findByUserId(userId).orElse(null);
        if (stats == null) return;

        stats.setTotalKills(stats.getTotalKills() + kills);
        stats.setTotalDeaths(stats.getTotalDeaths() + deaths);
        stats.setTotalDamage(stats.getTotalDamage() + damage);
        statsRepo.save(stats);
    }

    /**
     * Get a single player's ELO profile.
     */
    public EloDto getEloProfile(Long userId) {
        PlayerStats stats = statsRepo.findByUserId(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Stats not found"));
        return toDto(stats);
    }

    /**
     * Global ELO leaderboard, top 50 by rating.
     */
    public List<EloDto> getEloLeaderboard() {
        return statsRepo.findAll().stream()
                .sorted((a, b) -> Integer.compare(b.getEloRating(), a.getEloRating()))
                .limit(50)
                .map(this::toDto)
                .collect(Collectors.toList());
    }

    // ─── tier mapping ─────────────────────────────────────────

    public static String getTier(int elo) {
        if (elo >= 1800) return "MASTER";
        if (elo >= 1600) return "DIAMOND";
        if (elo >= 1400) return "PLATINUM";
        if (elo >= 1200) return "GOLD";
        if (elo >= 1000) return "SILVER";
        return "BRONZE";
    }

    // ─── mapping ──────────────────────────────────────────────

    private EloDto toDto(PlayerStats s) {
        EloDto dto = new EloDto();
        dto.setUserId(s.getUser().getId());
        dto.setUsername(s.getUser().getUsername());
        dto.setEloRating(s.getEloRating());
        dto.setTier(s.getTier());
        dto.setMatchesPlayed(s.getMatchesPlayed());
        dto.setMatchesWon(s.getMatchesWon());
        return dto;
    }
}
