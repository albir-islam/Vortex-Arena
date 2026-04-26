package com.example.arenashooter.repository;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import com.example.arenashooter.entity.RewardTransaction;

@Repository
public interface RewardTransactionRepository extends JpaRepository<RewardTransaction, Long> {
    Optional<RewardTransaction> findByUserIdAndMatchId(Long userId, String matchId);
    boolean existsByUserIdAndMatchId(Long userId, String matchId);
    List<RewardTransaction> findByUserIdOrderByCreatedAtDesc(Long userId);
}
