package com.example.arenashooter.repository;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import com.example.arenashooter.entity.TournamentMatch;

@Repository
public interface TournamentMatchRepository extends JpaRepository<TournamentMatch, Long> {
    List<TournamentMatch> findByTournamentIdOrderByRoundNumberAsc(Long tournamentId);
    List<TournamentMatch> findByTournamentIdAndRoundNumber(Long tournamentId, int roundNumber);
    List<TournamentMatch> findByTournamentIdAndStatus(Long tournamentId, String status);
}
