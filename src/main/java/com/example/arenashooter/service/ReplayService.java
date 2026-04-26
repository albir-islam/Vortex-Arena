package com.example.arenashooter.service;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.arenashooter.dto.MatchEventDto;
import com.example.arenashooter.entity.MatchEvent;
import com.example.arenashooter.repository.MatchEventRepository;

/**
 * Stores and retrieves timestamped match events for the replay system.
 * <p>
 * Events include MOVE, SHOOT, HIT, KILL, RESPAWN, etc.
 * The client can play them back to reconstruct the match visually.
 */
@Service
public class ReplayService {

    private final MatchEventRepository repo;

    public ReplayService(MatchEventRepository repo) {
        this.repo = repo;
    }

    /**
     * Record a single match event.
     */
    @Transactional
    public void recordEvent(String matchId, Long playerId, String eventType, String dataJson) {
        MatchEvent e = new MatchEvent();
        e.setMatchId(matchId);
        e.setPlayerId(playerId);
        e.setEventType(eventType);
        e.setEventTimestamp(System.currentTimeMillis());
        e.setDataJson(dataJson);
        repo.save(e);
    }

    /**
     * Get all events for a match, ordered chronologically — the full replay.
     */
    public List<MatchEventDto> getReplay(String matchId) {
        return repo.findByMatchIdOrderByEventTimestampAsc(matchId)
                .stream().map(this::toDto).collect(Collectors.toList());
    }

    /**
     * Get events for a specific player in a match.
     */
    public List<MatchEventDto> getPlayerEvents(String matchId, Long playerId) {
        return repo.findByMatchIdAndPlayerId(matchId, playerId)
                .stream().map(this::toDto).collect(Collectors.toList());
    }

    /**
     * Get events of a specific type in a match (e.g. all KILL events).
     */
    public List<MatchEventDto> getEventsByType(String matchId, String eventType) {
        return repo.findByMatchIdAndEventType(matchId, eventType)
                .stream().map(this::toDto).collect(Collectors.toList());
    }

    // ─── mapping ──────────────────────────────────────────────

    private MatchEventDto toDto(MatchEvent e) {
        MatchEventDto dto = new MatchEventDto();
        dto.setEventId(e.getEventId());
        dto.setMatchId(e.getMatchId());
        dto.setEventType(e.getEventType());
        dto.setPlayerId(e.getPlayerId());
        dto.setTimestamp(e.getEventTimestamp());
        dto.setDataJson(e.getDataJson());
        return dto;
    }
}
