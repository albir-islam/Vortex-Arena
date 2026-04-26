package com.example.arenashooter.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.example.arenashooter.dto.CosmeticDto;
import com.example.arenashooter.entity.Cosmetic;
import com.example.arenashooter.entity.UserCosmetic;
import com.example.arenashooter.repository.CosmeticRepository;
import com.example.arenashooter.repository.UserCosmeticRepository;

/**
 * Service for browsing, unlocking (purchasing), equipping and unequipping
 * cosmetic items (skins and effects).
 */
@Service
public class CosmeticService {

    private final CosmeticRepository cosmeticRepo;
    private final UserCosmeticRepository userCosmeticRepo;
    private final EconomyService economyService;

    public CosmeticService(CosmeticRepository cosmeticRepo,
                           UserCosmeticRepository userCosmeticRepo,
                           EconomyService economyService) {
        this.cosmeticRepo = cosmeticRepo;
        this.userCosmeticRepo = userCosmeticRepo;
        this.economyService = economyService;
    }

    /**
     * Return every cosmetic with owned/equipped flags for the given user.
     */
    public List<CosmeticDto> getAllCosmetics(Long userId) {
        List<Cosmetic> all = cosmeticRepo.findAll();
        List<UserCosmetic> owned = userCosmeticRepo.findByUserId(userId);

        return all.stream().map(c -> {
            CosmeticDto dto = toDto(c);
            Optional<UserCosmetic> uc = owned.stream()
                    .filter(o -> o.getCosmetic().getCosmeticId().equals(c.getCosmeticId()))
                    .findFirst();
            dto.setOwned(uc.isPresent());
            dto.setEquipped(uc.map(UserCosmetic::isEquipped).orElse(false));
            return dto;
        }).collect(Collectors.toList());
    }

    /**
     * Unlock (purchase) a cosmetic for the user.
     * Deducts coins via {@link EconomyService}.
     */
    @Transactional
    public CosmeticDto unlockCosmetic(Long userId, Long cosmeticId) {
        if (userCosmeticRepo.existsByUserIdAndCosmeticCosmeticId(userId, cosmeticId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Cosmetic already owned");
        }

        Cosmetic cosmetic = cosmeticRepo.findById(cosmeticId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Cosmetic not found"));

        // Spend coins (will throw 400 if insufficient)
        economyService.spendCoins(userId, cosmetic.getPrice());

        UserCosmetic uc = new UserCosmetic();
        uc.setUserId(userId);
        uc.setCosmetic(cosmetic);
        uc.setEquipped(false);
        uc.setUnlockedAt(LocalDateTime.now());
        userCosmeticRepo.save(uc);

        CosmeticDto dto = toDto(cosmetic);
        dto.setOwned(true);
        dto.setEquipped(false);
        return dto;
    }

    /**
     * Equip an owned cosmetic.
     */
    @Transactional
    public CosmeticDto equipCosmetic(Long userId, Long cosmeticId) {
        UserCosmetic uc = userCosmeticRepo.findByUserIdAndCosmeticCosmeticId(userId, cosmeticId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Cosmetic not owned"));

        // Unequip others of the same type so only one skin/effect is active
        String type = uc.getCosmetic().getType();
        List<UserCosmetic> equipped = userCosmeticRepo.findByUserIdAndEquipped(userId, true);
        for (UserCosmetic other : equipped) {
            if (other.getCosmetic().getType().equals(type)) {
                other.setEquipped(false);
                userCosmeticRepo.save(other);
            }
        }

        uc.setEquipped(true);
        userCosmeticRepo.save(uc);

        CosmeticDto dto = toDto(uc.getCosmetic());
        dto.setOwned(true);
        dto.setEquipped(true);
        return dto;
    }

    /**
     * Unequip a cosmetic.
     */
    @Transactional
    public CosmeticDto unequipCosmetic(Long userId, Long cosmeticId) {
        UserCosmetic uc = userCosmeticRepo.findByUserIdAndCosmeticCosmeticId(userId, cosmeticId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Cosmetic not owned"));
        uc.setEquipped(false);
        userCosmeticRepo.save(uc);

        CosmeticDto dto = toDto(uc.getCosmetic());
        dto.setOwned(true);
        dto.setEquipped(false);
        return dto;
    }

    // ─── helpers ──────────────────────────────────────────────

    private CosmeticDto toDto(Cosmetic c) {
        CosmeticDto dto = new CosmeticDto();
        dto.setCosmeticId(c.getCosmeticId());
        dto.setName(c.getName());
        dto.setType(c.getType());
        dto.setPrice(c.getPrice());
        dto.setAssetPath(c.getAssetPath());
        return dto;
    }
}
