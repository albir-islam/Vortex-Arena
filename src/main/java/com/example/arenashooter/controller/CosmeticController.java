package com.example.arenashooter.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.example.arenashooter.dto.CosmeticActionRequest;
import com.example.arenashooter.dto.CosmeticDto;
import com.example.arenashooter.service.CosmeticService;

/**
 * REST endpoints for the cosmetic / character customization system.
 */
@RestController
@RequestMapping("/api/cosmetics")
public class CosmeticController {

    private final CosmeticService cosmeticService;

    public CosmeticController(CosmeticService cosmeticService) {
        this.cosmeticService = cosmeticService;
    }

    /** GET /api/cosmetics?userId=1 — all cosmetics with owned/equipped flags */
    @GetMapping
    public ResponseEntity<List<CosmeticDto>> getAll(@RequestParam Long userId) {
        return ResponseEntity.ok(cosmeticService.getAllCosmetics(userId));
    }

    /** POST /api/cosmetics/unlock — purchase a cosmetic with coins */
    @PostMapping("/unlock")
    public ResponseEntity<CosmeticDto> unlock(@RequestBody CosmeticActionRequest request) {
        return ResponseEntity.ok(cosmeticService.unlockCosmetic(request.getUserId(), request.getCosmeticId()));
    }

    /** POST /api/cosmetics/equip — equip an owned cosmetic */
    @PostMapping("/equip")
    public ResponseEntity<CosmeticDto> equip(@RequestBody CosmeticActionRequest request) {
        return ResponseEntity.ok(cosmeticService.equipCosmetic(request.getUserId(), request.getCosmeticId()));
    }

    /** POST /api/cosmetics/unequip — unequip a cosmetic */
    @PostMapping("/unequip")
    public ResponseEntity<CosmeticDto> unequip(@RequestBody CosmeticActionRequest request) {
        return ResponseEntity.ok(cosmeticService.unequipCosmetic(request.getUserId(), request.getCosmeticId()));
    }
}
