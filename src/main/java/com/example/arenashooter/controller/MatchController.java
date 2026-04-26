package com.example.arenashooter.controller;

import java.util.Collections;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.arenashooter.model.GameMatch;
import com.example.arenashooter.service.MatchService;

@RestController
@RequestMapping("/api/match")
public class MatchController {

    private final MatchService matchService;

    public MatchController(MatchService matchService) {
        this.matchService = matchService;
    }

    @PostMapping("/join")
    public ResponseEntity<Map<String, String>> joinMatch(@RequestHeader("Authorization") String token) {
        // Real logic: validate token
        GameMatch match = matchService.findMatchForPlayer("user_from_token");
        return ResponseEntity.ok(Collections.singletonMap("matchId", match.getMatchId()));
    }

    @PostMapping("/leave")
    public ResponseEntity<Void> leaveMatch(@RequestHeader("Authorization") String token) {
        // Logic to remove player
        return ResponseEntity.ok().build();
    }
}
