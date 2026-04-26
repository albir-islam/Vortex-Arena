package com.example.arenashooter.repository;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import com.example.arenashooter.entity.MatchEvent;

@Repository
public interface MatchEventRepository extends JpaRepository<MatchEvent, Long> {
    List<MatchEvent> findByMatchIdOrderByEventTimestampAsc(String matchId);
    List<MatchEvent> findByMatchIdAndEventType(String matchId, String eventType);
    List<MatchEvent> findByMatchIdAndPlayerId(String matchId, Long playerId);
}
