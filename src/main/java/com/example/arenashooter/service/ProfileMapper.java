package com.example.arenashooter.service;

import org.springframework.stereotype.Component;

import com.example.arenashooter.dto.InventoryDto;
import com.example.arenashooter.dto.PlayerProfileDto;
import com.example.arenashooter.dto.PlayerStatsDto;
import com.example.arenashooter.entity.Inventory;
import com.example.arenashooter.entity.PlayerStats;
import com.example.arenashooter.entity.User;

@Component
public class ProfileMapper {
    public PlayerProfileDto toProfile(User user, Inventory inventory, PlayerStats stats) {
        PlayerProfileDto dto = new PlayerProfileDto();
        dto.setUserId(user.getId());
        dto.setUsername(user.getUsername());
        dto.setCurrentDress(user.getCurrentDress());
        dto.setInventory(toInventoryDto(inventory));
        dto.setStats(toStatsDto(stats));
        return dto;
    }

    private InventoryDto toInventoryDto(Inventory inventory) {
        InventoryDto dto = new InventoryDto();
        dto.setPrimaryWeapon(inventory.getPrimaryWeapon());
        dto.setSecondaryWeapon(inventory.getSecondaryWeapon());
        dto.setFirstAidCount(inventory.getFirstAidCount());
        dto.setMedkitCount(inventory.getMedkitCount());
        dto.setBoostCount(inventory.getBoostCount());
        dto.setHelmetLevel(inventory.getHelmetLevel());
        dto.setVestLevel(inventory.getVestLevel());
        return dto;
    }

    private PlayerStatsDto toStatsDto(PlayerStats stats) {
        PlayerStatsDto dto = new PlayerStatsDto();
        dto.setUserId(stats.getUser().getId());
        dto.setUsername(stats.getUser().getUsername());
        dto.setHighScore(stats.getHighScore());
        dto.setTotalKills(stats.getTotalKills());
        dto.setHealth(stats.getHealth());
        return dto;
    }
}
