package com.example.arenashooter.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.arenashooter.dto.PlayerStatsDto;
import com.example.arenashooter.service.GameService;

@RestController
@RequestMapping("/api")
public class LeaderboardController {

    private final GameService gameService;

    public LeaderboardController(GameService gameService) {
        this.gameService = gameService;
    }

    @GetMapping("/leaderboard")
    public ResponseEntity<List<PlayerStatsDto>> getLeaderboard() {
        return ResponseEntity.ok(gameService.getLeaderboard());
    }
}
