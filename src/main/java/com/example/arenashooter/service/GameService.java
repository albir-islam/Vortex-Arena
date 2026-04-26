package com.example.arenashooter.service;

import java.util.List;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import com.example.arenashooter.dto.HealRequest;
import com.example.arenashooter.dto.InventorySyncRequest;
import com.example.arenashooter.dto.KillUpdateRequest;
import com.example.arenashooter.dto.PlayerProfileDto;
import com.example.arenashooter.dto.PlayerStatsDto;
import com.example.arenashooter.dto.StatsUpdateRequest;
import com.example.arenashooter.dto.WeaponSwapRequest;
import com.example.arenashooter.entity.Inventory;
import com.example.arenashooter.entity.PlayerStats;
import com.example.arenashooter.entity.User;
import com.example.arenashooter.repository.InventoryRepository;
import com.example.arenashooter.repository.PlayerStatsRepository;
import com.example.arenashooter.repository.UserRepository;

@Service
public class GameService {
        private final UserRepository userRepository;
        private final PlayerStatsRepository playerStatsRepository;
        private final InventoryRepository inventoryRepository;
        private final ProfileMapper profileMapper;

        public GameService(UserRepository userRepository,
                        PlayerStatsRepository playerStatsRepository,
                        InventoryRepository inventoryRepository,
                        ProfileMapper profileMapper) {
                this.userRepository = userRepository;
                this.playerStatsRepository = playerStatsRepository;
                this.inventoryRepository = inventoryRepository;
                this.profileMapper = profileMapper;
        }

        public PlayerProfileDto startGame(Long userId) {
                User user = userRepository.findById(userId)
                                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));
                PlayerStats stats = playerStatsRepository.findByUserId(userId)
                                .orElseGet(() -> createDefaultStats(user));
                Inventory inventory = inventoryRepository.findByUserId(userId)
                                .orElseGet(() -> createDefaultInventory(user));
                return profileMapper.toProfile(user, inventory, stats);
        }

        public List<PlayerStatsDto> getLeaderboard() {
                // Simplified: return top 10 by high score
                // We'd map entity to DTO here
                return playerStatsRepository.findAll().stream()
                                .sorted((a, b) -> Integer.compare(b.getHighScore(), a.getHighScore()))
                                .limit(10)
                                .map(stats -> {
                                        PlayerStatsDto dto = new PlayerStatsDto();
                                        dto.setUserId(stats.getUser().getId());
                                        dto.setUsername(stats.getUser().getUsername());
                                        dto.setHighScore(stats.getHighScore());
                                        dto.setTotalKills(stats.getTotalKills());
                                        return dto;
                                })
                                .collect(Collectors.toList());
        }

        // INTERNAL SERVER USE ONLY (Trusted)
        public void recordKill(Long killerId, Long victimId, int score) {
                // Update Killer
                PlayerStats killerStats = playerStatsRepository.findByUserId(killerId).orElse(null);
                if (killerStats != null) {
                        killerStats.setTotalKills(killerStats.getTotalKills() + 1);
                        killerStats.setHighScore(killerStats.getHighScore() + score); // Additive score logic for match?
                        // Or max high score logic?
                        // Preserving "HighScore" as generic Max score across games
                        if (score > killerStats.getHighScore()) { // If this match score is higher?
                                // Complex logic: Are we tracking per-match score?
                                // For now, let's treat 'score' as points added to persistent high score
                                // But typically HighScore is max(current, best).
                                // Let's assume high score tracks accumulation for this simplified backend.
                                killerStats.setHighScore(killerStats.getHighScore() + score);
                        }
                        playerStatsRepository.save(killerStats);
                }

                // Update Victim? (Death count not in entity, maybe just stats)
        }

        // Deprecated/Refurbished for client requests if necessary
        // Removed direct "handleKill" from client access to prevent cheating

        public PlayerProfileDto updateStats(StatsUpdateRequest request) {
                // Only trusted sources should call this or remove entirely if fully server
                // authoritative
                // Keeping for backward compat if needed, but safer to remove
                return null;
        }

        public PlayerProfileDto healPlayer(HealRequest request) {
                // Logic for using Medkit items
                return null;
        }

        public PlayerProfileDto swapWeapons(WeaponSwapRequest request) {
                Inventory inventory = inventoryRepository.findByUserId(request.getUserId())
                                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                                                "Inventory not found"));
                inventory.setPrimaryWeapon(request.getPrimaryWeapon());
                inventory.setSecondaryWeapon(request.getSecondaryWeapon());
                inventoryRepository.save(inventory);
                PlayerStats stats = playerStatsRepository.findByUserId(request.getUserId())
                                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                                                "Stats not found"));
                User user = inventory.getUser();
                return profileMapper.toProfile(user, inventory, stats);
        }

        public PlayerProfileDto syncInventory(InventorySyncRequest request) {
                // Validate inventory state
                // ...
                return null;
        }

        private PlayerStats createDefaultStats(User user) {
                PlayerStats stats = new PlayerStats();
                stats.setUser(user);
                stats.setHighScore(0);
                stats.setTotalKills(0);
                stats.setHealth(100);
                return playerStatsRepository.save(stats);
        }

        private Inventory createDefaultInventory(User user) {
                Inventory inventory = new Inventory();
                inventory.setUser(user);
                inventory.setPrimaryWeapon("AKM");
                inventory.setSecondaryWeapon("UZI");
                inventory.setFirstAidCount(1);
                inventory.setMedkitCount(0);
                inventory.setBoostCount(1);
                inventory.setHelmetLevel(1);
                inventory.setVestLevel(1);
                return inventoryRepository.save(inventory);
        }

        private int clamp(int value, int min, int max) {
                return Math.max(min, Math.min(max, value));
        }
}
