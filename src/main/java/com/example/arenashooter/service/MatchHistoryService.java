package com.example.arenashooter.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.arenashooter.dto.MatchHistoryDto;
import com.example.arenashooter.entity.MatchHistory;
import com.example.arenashooter.repository.MatchHistoryRepository;

/**
 * Records per-player match results and provides history queries.
 */
@Service
public class MatchHistoryService {

    private final MatchHistoryRepository repo;

    public MatchHistoryService(MatchHistoryRepository repo) {
        this.repo = repo;
    }

    /**
     * Persist a new match history record (one per player per match).
     */
    @Transactional
    public MatchHistoryDto recordMatch(String matchId, Long playerId, int kills,
                                       int deaths, int damage, int placement, String result) {
        MatchHistory h = new MatchHistory();
        h.setMatchId(matchId);
        h.setPlayerId(playerId);
        h.setKills(kills);
        h.setDeaths(deaths);
        h.setDamage(damage);
        h.setPlacement(placement);
        h.setResult(result);
        h.setCreatedAt(LocalDateTime.now());
        repo.save(h);
        return toDto(h);
    }

    /**
     * Get a player's match history, newest first.
     */
    public List<MatchHistoryDto> getHistory(Long playerId) {
        return repo.findByPlayerIdOrderByCreatedAtDesc(playerId)
                .stream().map(this::toDto).collect(Collectors.toList());
    }

    /**
     * Get all players' records for a single match.
     */
    public List<MatchHistoryDto> getMatchDetails(String matchId) {
        return repo.findByMatchId(matchId)
                .stream().map(this::toDto).collect(Collectors.toList());
    }

    /**
     * Count wins for a player.
     */
    public long countWins(Long playerId) {
        return repo.countByPlayerIdAndResult(playerId, "WIN");
    }

    /**
     * Count total matches played.
     */
    public long countMatches(Long playerId) {
        return repo.countByPlayerId(playerId);
    }

    // ─── mapping ──────────────────────────────────────────────

    private MatchHistoryDto toDto(MatchHistory h) {
        MatchHistoryDto dto = new MatchHistoryDto();
        dto.setMatchId(h.getMatchId());
        dto.setPlayerId(h.getPlayerId());
        dto.setKills(h.getKills());
        dto.setDeaths(h.getDeaths());
        dto.setDamage(h.getDamage());
        dto.setPlacement(h.getPlacement());
        dto.setResult(h.getResult());
        dto.setTimestamp(h.getCreatedAt());
        return dto;
    }
}
