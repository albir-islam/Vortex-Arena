package com.example.arenashooter.repository;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import com.example.arenashooter.entity.SeasonRanking;

@Repository
public interface SeasonRankingRepository extends JpaRepository<SeasonRanking, Long> {
    List<SeasonRanking> findBySeasonIdOrderByEloSnapshotDesc(Long seasonId);
    Optional<SeasonRanking> findBySeasonIdAndUserId(Long seasonId, Long userId);
}
