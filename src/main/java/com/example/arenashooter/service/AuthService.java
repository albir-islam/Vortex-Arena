package com.example.arenashooter.service;

import java.util.Optional;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import com.example.arenashooter.dto.LoginRequest;
import com.example.arenashooter.dto.PlayerProfileDto;
import com.example.arenashooter.entity.Inventory;
import com.example.arenashooter.entity.PlayerStats;
import com.example.arenashooter.entity.User;
import com.example.arenashooter.repository.InventoryRepository;
import com.example.arenashooter.repository.PlayerStatsRepository;
import com.example.arenashooter.repository.UserRepository;

@Service
public class AuthService {
    private final UserRepository userRepository;
    private final PlayerStatsRepository playerStatsRepository;
    private final InventoryRepository inventoryRepository;
    private final ProfileMapper profileMapper;
    private final EconomyService economyService;

    public AuthService(UserRepository userRepository,
            PlayerStatsRepository playerStatsRepository,
            InventoryRepository inventoryRepository,
            ProfileMapper profileMapper,
            EconomyService economyService) {
        this.userRepository = userRepository;
        this.playerStatsRepository = playerStatsRepository;
        this.inventoryRepository = inventoryRepository;
        this.profileMapper = profileMapper;
        this.economyService = economyService;
    }

    public PlayerProfileDto login(LoginRequest request) {
        if (request.getUsername() == null || request.getPassword() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Username and password are required");
        }

        Optional<User> existing = userRepository.findByUsername(request.getUsername());
        User user = existing.orElseGet(() -> createUser(request));

        if (existing.isPresent() && !user.getPassword().equals(request.getPassword())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid credentials");
        }

        PlayerStats stats = playerStatsRepository.findByUserId(user.getId())
                .orElseGet(() -> createDefaultStats(user));
        Inventory inventory = inventoryRepository.findByUserId(user.getId())
                .orElseGet(() -> createDefaultInventory(user));

        // Ensure wallet exists for new users
        economyService.getOrCreateWallet(user.getId());

        return profileMapper.toProfile(user, inventory, stats);
    }

    private User createUser(LoginRequest request) {
        User user = new User();
        user.setUsername(request.getUsername());
        user.setPassword(request.getPassword());
        user.setCurrentDress("Default");
        return userRepository.save(user);
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
}
