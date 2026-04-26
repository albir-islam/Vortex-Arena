package com.example.arenashooter.service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.arenashooter.dto.AchievementDto;
import com.example.arenashooter.entity.Achievement;
import com.example.arenashooter.entity.PlayerStats;
import com.example.arenashooter.entity.UserAchievement;
import com.example.arenashooter.repository.AchievementRepository;
import com.example.arenashooter.repository.PlayerStatsRepository;
import com.example.arenashooter.repository.UserAchievementRepository;

/**
 * Automatically checks and awards achievements after match events.
 * <p>
 * Each {@link Achievement} row has a {@code conditionType} (e.g. "TOTAL_KILLS")
 * and a {@code conditionValue} threshold.  When a player's stats meet or exceed
 * the threshold the achievement is unlocked and coin/gem rewards are credited.
 */
@Service
public class AchievementService {

    private final AchievementRepository achievementRepo;
    private final UserAchievementRepository userAchRepo;
    private final PlayerStatsRepository statsRepo;
    private final EconomyService economyService;

    public AchievementService(AchievementRepository achievementRepo,
                              UserAchievementRepository userAchRepo,
                              PlayerStatsRepository statsRepo,
                              EconomyService economyService) {
        this.achievementRepo = achievementRepo;
        this.userAchRepo = userAchRepo;
        this.statsRepo = statsRepo;
        this.economyService = economyService;
    }

    /**
     * Return every achievement with the user's unlock status.
     */
    public List<AchievementDto> getAllAchievements(Long userId) {
        List<Achievement> all = achievementRepo.findAll();
        List<UserAchievement> unlocked = userAchRepo.findByUserId(userId);

        return all.stream().map(a -> {
            AchievementDto dto = toDto(a);
            unlocked.stream()
                    .filter(ua -> ua.getAchievement().getAchievementId().equals(a.getAchievementId()))
                    .findFirst()
                    .ifPresent(ua -> {
                        dto.setUnlocked(true);
                        dto.setUnlockedAt(ua.getUnlockedAt());
                    });
            return dto;
        }).collect(Collectors.toList());
    }

    /**
     * Evaluate all achievements for a player and unlock any newly earned ones.
     * Returns the list of achievements unlocked during this call.
     */
    @Transactional
    public List<AchievementDto> checkAchievements(Long userId) {
        PlayerStats stats = statsRepo.findByUserId(userId).orElse(null);
        if (stats == null) return List.of();

        List<Achievement> all = achievementRepo.findAll();
        List<AchievementDto> newlyUnlocked = new ArrayList<>();

        for (Achievement a : all) {
            // Already unlocked?
            if (userAchRepo.existsByUserIdAndAchievementAchievementId(userId, a.getAchievementId())) {
                continue;
            }

            if (meetsCondition(stats, a)) {
                // Unlock
                UserAchievement ua = new UserAchievement();
                ua.setUserId(userId);
                ua.setAchievement(a);
                ua.setUnlockedAt(LocalDateTime.now());
                userAchRepo.save(ua);

                // Credit rewards directly to wallet
                if (a.getRewardCoins() > 0) {
                    var wallet = economyService.getOrCreateWallet(userId);
                    wallet.addCoins(a.getRewardCoins());
                    // wallet is managed entity – saved at txn commit
                }
                if (a.getRewardGems() > 0) {
                    var wallet = economyService.getOrCreateWallet(userId);
                    wallet.addGems(a.getRewardGems());
                }

                AchievementDto dto = toDto(a);
                dto.setUnlocked(true);
                dto.setUnlockedAt(LocalDateTime.now());
                newlyUnlocked.add(dto);
            }
        }
        return newlyUnlocked;
    }

    // ─── condition evaluation ─────────────────────────────────

    private boolean meetsCondition(PlayerStats stats, Achievement a) {
        int threshold = a.getConditionValue();
        return switch (a.getConditionType()) {
            case "TOTAL_KILLS"    -> stats.getTotalKills() >= threshold;
            case "HIGH_SCORE"     -> stats.getHighScore() >= threshold;
            case "MATCHES_PLAYED" -> stats.getMatchesPlayed() >= threshold;
            case "MATCHES_WON"    -> stats.getMatchesWon() >= threshold;
            case "ELO_RATING"     -> stats.getEloRating() >= threshold;
            case "TOTAL_DAMAGE"   -> stats.getTotalDamage() >= threshold;
            case "TOTAL_DEATHS"   -> stats.getTotalDeaths() >= threshold;
            default -> false;
        };
    }

    // ─── mapping ──────────────────────────────────────────────

    private AchievementDto toDto(Achievement a) {
        AchievementDto dto = new AchievementDto();
        dto.setAchievementId(a.getAchievementId());
        dto.setName(a.getName());
        dto.setDescription(a.getDescription());
        dto.setRewardCoins(a.getRewardCoins());
        dto.setRewardGems(a.getRewardGems());
        dto.setConditionType(a.getConditionType());
        dto.setConditionValue(a.getConditionValue());
        dto.setUnlocked(false);
        dto.setUnlockedAt(null);
        return dto;
    }
}
