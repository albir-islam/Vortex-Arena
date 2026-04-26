package com.example.arenashooter.dto;

import java.time.LocalDateTime;
import java.util.List;

public class TournamentDto {
    private Long tournamentId;
    private String name;
    private String status;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private int maxPlayers;
    private int currentPlayers;
    private List<TournamentMatchDto> bracket;

    public Long getTournamentId() { return tournamentId; }
    public void setTournamentId(Long tournamentId) { this.tournamentId = tournamentId; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public LocalDateTime getStartTime() { return startTime; }
    public void setStartTime(LocalDateTime startTime) { this.startTime = startTime; }

    public LocalDateTime getEndTime() { return endTime; }
    public void setEndTime(LocalDateTime endTime) { this.endTime = endTime; }

    public int getMaxPlayers() { return maxPlayers; }
    public void setMaxPlayers(int maxPlayers) { this.maxPlayers = maxPlayers; }

    public int getCurrentPlayers() { return currentPlayers; }
    public void setCurrentPlayers(int currentPlayers) { this.currentPlayers = currentPlayers; }

    public List<TournamentMatchDto> getBracket() { return bracket; }
    public void setBracket(List<TournamentMatchDto> bracket) { this.bracket = bracket; }

    public static class TournamentMatchDto {
        private String matchId;
        private int roundNumber;
        private Long player1Id;
        private Long player2Id;
        private Long winnerId;
        private String status;

        public String getMatchId() { return matchId; }
        public void setMatchId(String matchId) { this.matchId = matchId; }

        public int getRoundNumber() { return roundNumber; }
        public void setRoundNumber(int roundNumber) { this.roundNumber = roundNumber; }

        public Long getPlayer1Id() { return player1Id; }
        public void setPlayer1Id(Long player1Id) { this.player1Id = player1Id; }

        public Long getPlayer2Id() { return player2Id; }
        public void setPlayer2Id(Long player2Id) { this.player2Id = player2Id; }

        public Long getWinnerId() { return winnerId; }
        public void setWinnerId(Long winnerId) { this.winnerId = winnerId; }

        public String getStatus() { return status; }
        public void setStatus(String status) { this.status = status; }
    }
}
