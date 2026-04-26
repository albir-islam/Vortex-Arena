package com.example.arenashooter.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.arenashooter.dto.HealRequest;
import com.example.arenashooter.dto.InventorySyncRequest;
import com.example.arenashooter.dto.PlayerProfileDto;
import com.example.arenashooter.dto.StatsUpdateRequest;
import com.example.arenashooter.dto.WeaponSwapRequest;
import com.example.arenashooter.service.GameService;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class GameController {
    private final GameService gameService;

    public GameController(GameService gameService) {
        this.gameService = gameService;
    }

    @GetMapping("/player/profile")
    public ResponseEntity<PlayerProfileDto> getProfile(@RequestParam Long userId) {
        // Renamed from start -> player/profile to match request
        PlayerProfileDto profile = gameService.startGame(userId);
        return ResponseEntity.ok(profile);
    }

    // Legacy support via alias if needed:
    @GetMapping("/start")
    public ResponseEntity<PlayerProfileDto> startGame(@RequestParam Long userId) {
        return getProfile(userId);
    }

    // Deprecated Client-Side Logic Stubs (Must be server controlled now)

    @PostMapping("/update-stats")
    public ResponseEntity<Void> updateStats(@RequestBody StatsUpdateRequest request) {
        // Disabled for security
        return ResponseEntity.badRequest().build();
    }

    @PostMapping("/sync-inventory")
    public ResponseEntity<PlayerProfileDto> syncInventory(@RequestBody InventorySyncRequest request) {
        PlayerProfileDto profile = gameService.syncInventory(request);
        return ResponseEntity.ok(profile);
    }

    // Removed handleKill - Kill logic is now Server Authoritative via WebSocket

    @PostMapping("/heal")
    public ResponseEntity<PlayerProfileDto> heal(@RequestBody HealRequest request) {
        PlayerProfileDto profile = gameService.healPlayer(request);
        return ResponseEntity.ok(profile);
    }

    @PostMapping("/swap-weapons")
    public ResponseEntity<PlayerProfileDto> swapWeapons(@RequestBody WeaponSwapRequest request) {
        PlayerProfileDto profile = gameService.swapWeapons(request);
        return ResponseEntity.ok(profile);
    }
}
