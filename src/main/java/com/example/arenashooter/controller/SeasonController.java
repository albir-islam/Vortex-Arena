package com.example.arenashooter.controller;

import java.time.LocalDate;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.arenashooter.dto.SeasonLeaderboardDto;
import com.example.arenashooter.entity.Season;
import com.example.arenashooter.service.SeasonService;

/**
 * REST endpoints for seasonal leaderboards.
 */
@RestController
@RequestMapping("/api/seasons")
public class SeasonController {

    private final SeasonService seasonService;

    public SeasonController(SeasonService seasonService) {
        this.seasonService = seasonService;
    }

    /** GET /api/seasons/current — active season info */
    @GetMapping("/current")
    public ResponseEntity<Season> getCurrentSeason() {
        return seasonService.getCurrentSeason()
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /** GET /api/seasons/{seasonId}/leaderboard — ranked entries for a season */
    @GetMapping("/{seasonId}/leaderboard")
    public ResponseEntity<SeasonLeaderboardDto> getLeaderboard(@PathVariable Long seasonId) {
        return ResponseEntity.ok(seasonService.getSeasonLeaderboard(seasonId));
    }

    /** POST /api/seasons/{seasonId}/snapshot — freeze current ELO into season rankings */
    @PostMapping("/{seasonId}/snapshot")
    public ResponseEntity<Void> snapshot(@PathVariable Long seasonId) {
        seasonService.snapshotRankings(seasonId);
        return ResponseEntity.ok().build();
    }

    /** POST /api/seasons/new — end current season and start a new one */
    @PostMapping("/new")
    public ResponseEntity<Season> newSeason(@RequestParam String name,
                                            @RequestParam String startDate,
                                            @RequestParam String endDate) {
        Season s = seasonService.endSeasonAndStartNew(name,
                LocalDate.parse(startDate), LocalDate.parse(endDate));
        return ResponseEntity.ok(s);
    }
}
