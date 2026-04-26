package com.example.arenashooter.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.arenashooter.dto.MatchEventDto;
import com.example.arenashooter.service.ReplayService;

/**
 * REST endpoints for the replay system.
 */
@RestController
@RequestMapping("/api/replays")
public class ReplayController {

    private final ReplayService replayService;

    public ReplayController(ReplayService replayService) {
        this.replayService = replayService;
    }

    /** GET /api/replays/{matchId} — full replay event stream */
    @GetMapping("/{matchId}")
    public ResponseEntity<List<MatchEventDto>> getReplay(@PathVariable String matchId) {
        return ResponseEntity.ok(replayService.getReplay(matchId));
    }

    /** GET /api/replays/{matchId}/player/{playerId} — events for one player */
    @GetMapping("/{matchId}/player/{playerId}")
    public ResponseEntity<List<MatchEventDto>> getPlayerEvents(@PathVariable String matchId,
                                                               @PathVariable Long playerId) {
        return ResponseEntity.ok(replayService.getPlayerEvents(matchId, playerId));
    }

    /** GET /api/replays/{matchId}/type/{eventType} — events by type (KILL, SHOOT, etc.) */
    @GetMapping("/{matchId}/type/{eventType}")
    public ResponseEntity<List<MatchEventDto>> getByType(@PathVariable String matchId,
                                                         @PathVariable String eventType) {
        return ResponseEntity.ok(replayService.getEventsByType(matchId, eventType));
    }
}
