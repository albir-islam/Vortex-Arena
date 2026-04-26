package com.example.arenashooter.service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.UUID;

import org.springframework.stereotype.Service;

import com.example.arenashooter.model.GameMatch;
import com.example.arenashooter.model.GamePlayer;

@Service
public class MatchService {

    // Active Matches: MatchId -> GameMatch
    private final Map<String, GameMatch> matches = new ConcurrentHashMap<>();

    public GameMatch createMatch() {
        String matchId = UUID.randomUUID().toString();
        GameMatch match = new GameMatch(matchId);
        matches.put(matchId, match);
        return match;
    }

    public GameMatch getMatch(String matchId) {
        return matches.get(matchId);
    }

    public GameMatch findMatchForPlayer(String playerId) {
        // Simplified: Just default to a "lobby" or "match_1" if simplistic
        // Or search all matches
        return matches.values().stream().findFirst().orElseGet(this::createMatch);
    }

    public void removeMatch(String matchId) {
        matches.remove(matchId);
    }
}
