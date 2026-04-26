package com.example.arenashooter.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.arenashooter.dto.EloDto;
import com.example.arenashooter.service.EloService;

/**
 * REST endpoints for ELO ranking.
 */
@RestController
@RequestMapping("/api/elo")
public class EloController {

    private final EloService eloService;

    public EloController(EloService eloService) {
        this.eloService = eloService;
    }

    /** GET /api/elo/profile?userId=1 — single player ELO profile */
    @GetMapping("/profile")
    public ResponseEntity<EloDto> getProfile(@RequestParam Long userId) {
        return ResponseEntity.ok(eloService.getEloProfile(userId));
    }

    /** GET /api/elo/leaderboard — global top 50 by ELO rating */
    @GetMapping("/leaderboard")
    public ResponseEntity<List<EloDto>> getLeaderboard() {
        return ResponseEntity.ok(eloService.getEloLeaderboard());
    }
}
