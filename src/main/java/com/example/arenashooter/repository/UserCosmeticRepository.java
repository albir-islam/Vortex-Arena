package com.example.arenashooter.repository;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import com.example.arenashooter.entity.UserCosmetic;

@Repository
public interface UserCosmeticRepository extends JpaRepository<UserCosmetic, Long> {
    List<UserCosmetic> findByUserId(Long userId);
    List<UserCosmetic> findByUserIdAndEquipped(Long userId, boolean equipped);
    Optional<UserCosmetic> findByUserIdAndCosmeticCosmeticId(Long userId, Long cosmeticId);
    boolean existsByUserIdAndCosmeticCosmeticId(Long userId, Long cosmeticId);
}
