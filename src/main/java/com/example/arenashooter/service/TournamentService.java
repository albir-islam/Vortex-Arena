package com.example.arenashooter.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.example.arenashooter.dto.TournamentDto;
import com.example.arenashooter.entity.Tournament;
import com.example.arenashooter.entity.TournamentMatch;
import com.example.arenashooter.entity.TournamentParticipant;
import com.example.arenashooter.repository.TournamentMatchRepository;
import com.example.arenashooter.repository.TournamentParticipantRepository;
import com.example.arenashooter.repository.TournamentRepository;
import com.example.arenashooter.repository.UserRepository;

/**
 * Single-elimination bracket tournament system.
 * <ol>
 *   <li>Create tournament with max players</li>
 *   <li>Players join (capped at max)</li>
 *   <li>Admin generates bracket → first round matches</li>
 *   <li>Report results → winners advance to next round</li>
 * </ol>
 */
@Service
public class TournamentService {

    private final TournamentRepository tournamentRepo;
    private final TournamentParticipantRepository participantRepo;
    private final TournamentMatchRepository matchRepo;
    private final UserRepository userRepo;

    public TournamentService(TournamentRepository tournamentRepo,
                             TournamentParticipantRepository participantRepo,
                             TournamentMatchRepository matchRepo,
                             UserRepository userRepo) {
        this.tournamentRepo = tournamentRepo;
        this.participantRepo = participantRepo;
        this.matchRepo = matchRepo;
        this.userRepo = userRepo;
    }

    // ─── CRUD ─────────────────────────────────────────────────

    @Transactional
    public TournamentDto createTournament(String name, int maxPlayers, LocalDateTime startTime) {
        Tournament t = new Tournament();
        t.setName(name);
        t.setStatus("REGISTRATION");
        t.setMaxPlayers(maxPlayers);
        t.setStartTime(startTime);
        t.setCreatedAt(LocalDateTime.now());
        tournamentRepo.save(t);
        return toDto(t);
    }

    public TournamentDto getTournament(Long tournamentId) {
        Tournament t = tournamentRepo.findById(tournamentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Tournament not found"));
        return toDto(t);
    }

    public List<TournamentDto> getTournamentsByStatus(String status) {
        return tournamentRepo.findByStatus(status).stream()
                .map(this::toDto).collect(Collectors.toList());
    }

    // ─── join ─────────────────────────────────────────────────

    @Transactional
    public TournamentDto joinTournament(Long tournamentId, Long userId) {
        Tournament t = tournamentRepo.findById(tournamentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Tournament not found"));

        if (!"REGISTRATION".equals(t.getStatus())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Registration closed");
        }
        if (participantRepo.existsByTournamentIdAndUserId(tournamentId, userId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Already joined");
        }

        long currentCount = participantRepo.findByTournamentId(tournamentId).size();
        if (currentCount >= t.getMaxPlayers()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Tournament full");
        }

        // Verify user exists
        userRepo.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        TournamentParticipant tp = new TournamentParticipant();
        tp.setTournamentId(tournamentId);
        tp.setUserId(userId);
        tp.setSeed((int) (currentCount + 1));
        tp.setEliminated(false);
        participantRepo.save(tp);

        return toDto(t);
    }

    // ─── bracket generation ───────────────────────────────────

    /**
     * Generate round-1 bracket from seeded participants.
     * Pairs seed 1 vs last, 2 vs second-last, etc.
     */
    @Transactional
    public TournamentDto generateBracket(Long tournamentId) {
        Tournament t = tournamentRepo.findById(tournamentId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Tournament not found"));

        if (!"REGISTRATION".equals(t.getStatus())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Bracket can only be generated during registration");
        }

        List<TournamentParticipant> participants = participantRepo.findByTournamentId(tournamentId);
        if (participants.size() < 2) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Need at least 2 participants");
        }

        // Sort by seed
        participants.sort((a, b) -> Integer.compare(a.getSeed(), b.getSeed()));

        // Pair top seed vs bottom seed
        int round = 1;
        int i = 0, j = participants.size() - 1;
        while (i < j) {
            TournamentMatch tm = new TournamentMatch();
            tm.setTournamentId(tournamentId);
            tm.setMatchId(UUID.randomUUID().toString());
            tm.setRoundNumber(round);
            tm.setPlayer1Id(participants.get(i).getUserId());
            tm.setPlayer2Id(participants.get(j).getUserId());
            tm.setStatus("PENDING");
            tm.setCreatedAt(LocalDateTime.now());
            matchRepo.save(tm);
            i++;
            j--;
        }

        // If odd number, last player gets a BYE (auto-advance)
        if (participants.size() % 2 != 0) {
            TournamentParticipant byePlayer = participants.get(i);
            TournamentMatch tm = new TournamentMatch();
            tm.setTournamentId(tournamentId);
            tm.setMatchId("BYE-" + UUID.randomUUID());
            tm.setRoundNumber(round);
            tm.setPlayer1Id(byePlayer.getUserId());
            tm.setPlayer2Id(null);
            tm.setWinnerId(byePlayer.getUserId());
            tm.setStatus("COMPLETED");
            tm.setCreatedAt(LocalDateTime.now());
            matchRepo.save(tm);
        }

        t.setStatus("IN_PROGRESS");
        tournamentRepo.save(t);

        return toDto(t);
    }

    // ─── report result ────────────────────────────────────────

    /**
     * Report the winner of a tournament match. Loser is eliminated.
     * If all matches in the current round are complete, generate next-round matches.
     */
    @Transactional
    public TournamentDto reportResult(Long tournamentMatchId, Long winnerId) {
        TournamentMatch tm = matchRepo.findById(tournamentMatchId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Match not found"));

        if ("COMPLETED".equals(tm.getStatus())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Match already completed");
        }

        // Validate winner is a participant in this match
        if (!winnerId.equals(tm.getPlayer1Id()) && !winnerId.equals(tm.getPlayer2Id())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Winner not in this match");
        }

        tm.setWinnerId(winnerId);
        tm.setStatus("COMPLETED");
        matchRepo.save(tm);

        // Eliminate loser
        Long loserId = winnerId.equals(tm.getPlayer1Id()) ? tm.getPlayer2Id() : tm.getPlayer1Id();
        if (loserId != null) {
            participantRepo.findByTournamentId(tm.getTournamentId()).stream()
                    .filter(p -> p.getUserId().equals(loserId))
                    .findFirst()
                    .ifPresent(p -> {
                        p.setEliminated(true);
                        participantRepo.save(p);
                    });
        }

        // Check if round is complete → generate next round
        advanceRoundIfComplete(tm.getTournamentId(), tm.getRoundNumber());

        return toDto(tournamentRepo.findById(tm.getTournamentId()).orElse(null));
    }

    private void advanceRoundIfComplete(Long tournamentId, int currentRound) {
        List<TournamentMatch> roundMatches = matchRepo.findByTournamentIdAndRoundNumber(tournamentId, currentRound);
        boolean allDone = roundMatches.stream().allMatch(m -> "COMPLETED".equals(m.getStatus()));
        if (!allDone) return;

        List<Long> winners = roundMatches.stream()
                .map(TournamentMatch::getWinnerId)
                .collect(Collectors.toList());

        if (winners.size() <= 1) {
            // Tournament finished
            Tournament t = tournamentRepo.findById(tournamentId).orElse(null);
            if (t != null) {
                t.setStatus("COMPLETED");
                t.setEndTime(LocalDateTime.now());
                tournamentRepo.save(t);
            }
            return;
        }

        // Generate next round
        int nextRound = currentRound + 1;
        for (int i = 0; i + 1 < winners.size(); i += 2) {
            TournamentMatch tm = new TournamentMatch();
            tm.setTournamentId(tournamentId);
            tm.setMatchId(UUID.randomUUID().toString());
            tm.setRoundNumber(nextRound);
            tm.setPlayer1Id(winners.get(i));
            tm.setPlayer2Id(winners.get(i + 1));
            tm.setStatus("PENDING");
            tm.setCreatedAt(LocalDateTime.now());
            matchRepo.save(tm);
        }

        // Odd winner gets BYE
        if (winners.size() % 2 != 0) {
            Long byeWinner = winners.get(winners.size() - 1);
            TournamentMatch tm = new TournamentMatch();
            tm.setTournamentId(tournamentId);
            tm.setMatchId("BYE-" + UUID.randomUUID());
            tm.setRoundNumber(nextRound);
            tm.setPlayer1Id(byeWinner);
            tm.setPlayer2Id(null);
            tm.setWinnerId(byeWinner);
            tm.setStatus("COMPLETED");
            tm.setCreatedAt(LocalDateTime.now());
            matchRepo.save(tm);

            // Re-check if this BYE + other matches completes the round immediately
            // (only relevant when there was just one non-BYE match)
        }
    }

    // ─── mapping ──────────────────────────────────────────────

    private TournamentDto toDto(Tournament t) {
        if (t == null) return null;

        TournamentDto dto = new TournamentDto();
        dto.setTournamentId(t.getTournamentId());
        dto.setName(t.getName());
        dto.setStatus(t.getStatus());
        dto.setStartTime(t.getStartTime());
        dto.setEndTime(t.getEndTime());
        dto.setMaxPlayers(t.getMaxPlayers());

        long currentPlayers = participantRepo.findByTournamentId(t.getTournamentId()).size();
        dto.setCurrentPlayers((int) currentPlayers);

        // Bracket
        List<TournamentMatch> matches = matchRepo.findByTournamentIdOrderByRoundNumberAsc(t.getTournamentId());
        dto.setBracket(matches.stream().map(m -> {
            TournamentDto.TournamentMatchDto md = new TournamentDto.TournamentMatchDto();
            md.setMatchId(m.getMatchId());
            md.setRoundNumber(m.getRoundNumber());
            md.setPlayer1Id(m.getPlayer1Id());
            md.setPlayer2Id(m.getPlayer2Id());
            md.setWinnerId(m.getWinnerId());
            md.setStatus(m.getStatus());
            return md;
        }).collect(Collectors.toList()));

        return dto;
    }
}
