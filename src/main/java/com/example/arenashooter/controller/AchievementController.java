package com.example.arenashooter.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.arenashooter.dto.AchievementDto;
import com.example.arenashooter.service.AchievementService;

/**
 * REST endpoints for the achievement system.
 */
@RestController
@RequestMapping("/api/achievements")
public class AchievementController {

    private final AchievementService achievementService;

    public AchievementController(AchievementService achievementService) {
        this.achievementService = achievementService;
    }

    /** GET /api/achievements?userId=1 — all achievements with unlock status */
    @GetMapping
    public ResponseEntity<List<AchievementDto>> getAll(@RequestParam Long userId) {
        return ResponseEntity.ok(achievementService.getAllAchievements(userId));
    }

    /** POST /api/achievements/check?userId=1 — trigger achievement evaluation */
    @PostMapping("/check")
    public ResponseEntity<List<AchievementDto>> check(@RequestParam Long userId) {
        return ResponseEntity.ok(achievementService.checkAchievements(userId));
    }
}
