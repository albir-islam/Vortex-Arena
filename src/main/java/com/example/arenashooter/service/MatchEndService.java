package com.example.arenashooter.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.arenashooter.dto.AchievementDto;
import com.example.arenashooter.dto.MatchRewardRequest;
import com.example.arenashooter.dto.RewardResultDto;
import com.example.arenashooter.multiplayer.model.MatchState;
import com.example.arenashooter.multiplayer.model.PlayerState;

/**
 * Orchestrates all post-match processing:
 * <ol>
 *   <li>Record match history for each player</li>
 *   <li>Grant coin/gem rewards</li>
 *   <li>Update ELO ratings</li>
 *   <li>Update aggregate player stats (kills, deaths, damage)</li>
 *   <li>Check achievements</li>
 * </ol>
 * <p>
 * Called by the multiplayer WebSocket handler when a match ends.
 */
@Service
public class MatchEndService {

    private final MatchHistoryService historyService;
    private final EconomyService economyService;
    private final EloService eloService;
    private final AchievementService achievementService;

    public MatchEndService(MatchHistoryService historyService,
                           EconomyService economyService,
                           EloService eloService,
                           AchievementService achievementService) {
        this.historyService = historyService;
        this.economyService = economyService;
        this.eloService = eloService;
        this.achievementService = achievementService;
    }

    /**
     * Process end-of-match for all players in a finished {@link MatchState}.
     * <p>
     * Each player is identified by their <em>string</em> playerId which must be
     * parseable to a {@link Long} to map to the database User id.
     */
    @Transactional
    public void processMatchEnd(MatchState match) {
        if (match == null) return;

        List<PlayerState> scoreboard = match.getScoreboard(); // sorted by score desc
        int totalPlayers = scoreboard.size();
        if (totalPlayers == 0) return;

        // The top-scoring player is the "winner"
        PlayerState winner = scoreboard.get(0);

        // Compute average ELO for the lobby (simplified: use 1000 default)
        int avgElo = 1000; // could query DB, but keeping it simple

        for (int i = 0; i < totalPlayers; i++) {
            PlayerState p = scoreboard.get(i);
            Long userId = parseUserId(p.getPlayerId());
            if (userId == null) continue; // skip bots/unparseable

            boolean won = p.getPlayerId().equals(winner.getPlayerId());
            boolean mvp = (i == 0); // top scorer
            int placement = i + 1;
            int kills = p.getPlayerKills() + p.getZombieKills();
            int deaths = 0;  // deaths aren't tracked in PlayerState – default 0
            int damage = p.getScore(); // rough proxy

            // 1. Match history
            historyService.recordMatch(
                    match.getMatchId(), userId,
                    kills, deaths, damage, placement,
                    won ? "WIN" : "LOSS");

            // 2. Economy rewards
            MatchRewardRequest req = new MatchRewardRequest();
            req.setUserId(userId);
            req.setMatchId(match.getMatchId());
            req.setKills(kills);
            req.setWon(won);
            req.setMvp(mvp);
            req.setDamage(damage);
            req.setDeaths(deaths);
            req.setPlacement(placement);
            economyService.rewardForMatch(req);

            // 3. ELO update
            eloService.calculateAndUpdate(userId, avgElo, won);

            // 4. Aggregate stats
            eloService.recordMatchStats(userId, kills, deaths, damage);

            // 5. Achievement check
            achievementService.checkAchievements(userId);
        }
    }

    /**
     * Try to parse the WebSocket playerId (String) to a database userId (Long).
     * Returns null if un-parseable.
     */
    private Long parseUserId(String playerId) {
        if (playerId == null) return null;
        try {
            return Long.parseLong(playerId);
        } catch (NumberFormatException e) {
            // Could be username-based; caller responsible for mapping
            return null;
        }
    }
}
