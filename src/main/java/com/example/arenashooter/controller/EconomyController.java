package com.example.arenashooter.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.arenashooter.dto.MatchRewardRequest;
import com.example.arenashooter.dto.RewardResultDto;
import com.example.arenashooter.dto.WalletDto;
import com.example.arenashooter.service.EconomyService;

/**
 * REST endpoints for the coin / gem economy.
 */
@RestController
@RequestMapping("/api/economy")
public class EconomyController {

    private final EconomyService economyService;

    public EconomyController(EconomyService economyService) {
        this.economyService = economyService;
    }

    /** GET /api/economy/wallet?userId=1 */
    @GetMapping("/wallet")
    public ResponseEntity<WalletDto> getWallet(@RequestParam Long userId) {
        return ResponseEntity.ok(economyService.getWallet(userId));
    }

    /** POST /api/economy/reward  — grant match rewards (server-side call) */
    @PostMapping("/reward")
    public ResponseEntity<RewardResultDto> rewardForMatch(@RequestBody MatchRewardRequest request) {
        return ResponseEntity.ok(economyService.rewardForMatch(request));
    }
}
