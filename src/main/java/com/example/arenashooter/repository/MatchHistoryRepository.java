package com.example.arenashooter.repository;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import com.example.arenashooter.entity.MatchHistory;

@Repository
public interface MatchHistoryRepository extends JpaRepository<MatchHistory, Long> {
    List<MatchHistory> findByPlayerIdOrderByCreatedAtDesc(Long playerId);
    List<MatchHistory> findByMatchId(String matchId);
    long countByPlayerIdAndResult(Long playerId, String result);
    long countByPlayerId(Long playerId);
}
