package com.example.arenashooter.controller;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.arenashooter.dto.TournamentDto;
import com.example.arenashooter.service.TournamentService;

/**
 * REST endpoints for the tournament system.
 */
@RestController
@RequestMapping("/api/tournaments")
public class TournamentController {

    private final TournamentService tournamentService;

    public TournamentController(TournamentService tournamentService) {
        this.tournamentService = tournamentService;
    }

    /** POST /api/tournaments — create a new tournament */
    @PostMapping
    public ResponseEntity<TournamentDto> create(@RequestBody Map<String, Object> body) {
        String name = (String) body.get("name");
        int maxPlayers = ((Number) body.get("maxPlayers")).intValue();
        LocalDateTime startTime = body.containsKey("startTime")
                ? LocalDateTime.parse((String) body.get("startTime"))
                : null;
        return ResponseEntity.ok(tournamentService.createTournament(name, maxPlayers, startTime));
    }

    /** GET /api/tournaments/{id} — get tournament with full bracket */
    @GetMapping("/{id}")
    public ResponseEntity<TournamentDto> get(@PathVariable Long id) {
        return ResponseEntity.ok(tournamentService.getTournament(id));
    }

    /** GET /api/tournaments?status=REGISTRATION — list by status */
    @GetMapping
    public ResponseEntity<List<TournamentDto>> listByStatus(@RequestParam(defaultValue = "REGISTRATION") String status) {
        return ResponseEntity.ok(tournamentService.getTournamentsByStatus(status));
    }

    /** POST /api/tournaments/{id}/join?userId=1 — join a tournament */
    @PostMapping("/{id}/join")
    public ResponseEntity<TournamentDto> join(@PathVariable Long id, @RequestParam Long userId) {
        return ResponseEntity.ok(tournamentService.joinTournament(id, userId));
    }

    /** POST /api/tournaments/{id}/bracket — generate bracket and start */
    @PostMapping("/{id}/bracket")
    public ResponseEntity<TournamentDto> generateBracket(@PathVariable Long id) {
        return ResponseEntity.ok(tournamentService.generateBracket(id));
    }

    /** POST /api/tournaments/matches/{matchId}/result?winnerId=1 — report match result */
    @PostMapping("/matches/{matchId}/result")
    public ResponseEntity<TournamentDto> reportResult(@PathVariable Long matchId,
                                                      @RequestParam Long winnerId) {
        return ResponseEntity.ok(tournamentService.reportResult(matchId, winnerId));
    }
}
