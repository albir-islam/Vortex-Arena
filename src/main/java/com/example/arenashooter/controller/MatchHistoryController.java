package com.example.arenashooter.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.arenashooter.dto.MatchHistoryDto;
import com.example.arenashooter.service.MatchHistoryService;

/**
 * REST endpoints for match history.
 */
@RestController
@RequestMapping("/api/history")
public class MatchHistoryController {

    private final MatchHistoryService historyService;

    public MatchHistoryController(MatchHistoryService historyService) {
        this.historyService = historyService;
    }

    /** GET /api/history?playerId=1 — player's match history, newest first */
    @GetMapping
    public ResponseEntity<List<MatchHistoryDto>> getHistory(@RequestParam Long playerId) {
        return ResponseEntity.ok(historyService.getHistory(playerId));
    }

    /** GET /api/history/match/{matchId} — all players' records for a match */
    @GetMapping("/match/{matchId}")
    public ResponseEntity<List<MatchHistoryDto>> getMatchDetails(@PathVariable String matchId) {
        return ResponseEntity.ok(historyService.getMatchDetails(matchId));
    }
}
