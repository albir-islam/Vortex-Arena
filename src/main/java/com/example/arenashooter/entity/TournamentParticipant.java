package com.example.arenashooter.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "tournament_participants",
       uniqueConstraints = @UniqueConstraint(columnNames = {"tournament_id", "user_id"}))
public class TournamentParticipant {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tournament_id", nullable = false)
    private Long tournamentId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(nullable = false)
    private int seed = 0;

    @Column(nullable = false)
    private boolean eliminated = false;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getTournamentId() { return tournamentId; }
    public void setTournamentId(Long tournamentId) { this.tournamentId = tournamentId; }

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public int getSeed() { return seed; }
    public void setSeed(int seed) { this.seed = seed; }

    public boolean isEliminated() { return eliminated; }
    public void setEliminated(boolean eliminated) { this.eliminated = eliminated; }
}
