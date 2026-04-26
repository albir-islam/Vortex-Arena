package com.example.arenashooter.service;

import java.time.LocalDateTime;
import java.util.Optional;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.example.arenashooter.dto.MatchRewardRequest;
import com.example.arenashooter.dto.RewardResultDto;
import com.example.arenashooter.dto.WalletDto;
import com.example.arenashooter.entity.CurrencyWallet;
import com.example.arenashooter.entity.RewardTransaction;
import com.example.arenashooter.entity.User;
import com.example.arenashooter.repository.CurrencyWalletRepository;
import com.example.arenashooter.repository.RewardTransactionRepository;
import com.example.arenashooter.repository.UserRepository;

/**
 * Manages the coin/gem economy: wallets, match rewards, and spending.
 */
@Service
public class EconomyService {

    private static final int COINS_PER_KILL = 10;
    private static final int COINS_WIN_BONUS = 50;
    private static final int COINS_MVP_BONUS = 30;
    private static final int COINS_PARTICIPATION = 5;
    private static final int GEMS_WIN_BONUS = 2;
    private static final int GEMS_MVP_BONUS = 1;

    private final CurrencyWalletRepository walletRepo;
    private final RewardTransactionRepository txnRepo;
    private final UserRepository userRepo;

    public EconomyService(CurrencyWalletRepository walletRepo,
                          RewardTransactionRepository txnRepo,
                          UserRepository userRepo) {
        this.walletRepo = walletRepo;
        this.txnRepo = txnRepo;
        this.userRepo = userRepo;
    }

    /** Get or lazily create a wallet for the user. */
    public WalletDto getWallet(Long userId) {
        CurrencyWallet wallet = getOrCreateWallet(userId);
        return toDto(wallet);
    }

    /**
     * Calculate and grant rewards for a completed match.
     * Idempotent: if a reward for (userId, matchId) already exists it returns
     * the cached result without double-crediting.
     */
    @Transactional
    public RewardResultDto rewardForMatch(MatchRewardRequest req) {
        // Idempotency check
        if (txnRepo.existsByUserIdAndMatchId(req.getUserId(), req.getMatchId())) {
            CurrencyWallet wallet = getOrCreateWallet(req.getUserId());
            RewardResultDto dto = new RewardResultDto();
            dto.setUserId(req.getUserId());
            dto.setMatchId(req.getMatchId());
            dto.setCoinsEarned(0);
            dto.setGemsEarned(0);
            dto.setReason("ALREADY_REWARDED");
            dto.setTotalCoins(wallet.getCoins());
            dto.setTotalGems(wallet.getGems());
            dto.setAlreadyRewarded(true);
            return dto;
        }

        // Calculate rewards
        int coins = COINS_PARTICIPATION;
        int gems = 0;
        coins += req.getKills() * COINS_PER_KILL;
        if (req.isWon()) {
            coins += COINS_WIN_BONUS;
            gems += GEMS_WIN_BONUS;
        }
        if (req.isMvp()) {
            coins += COINS_MVP_BONUS;
            gems += GEMS_MVP_BONUS;
        }

        // Credit wallet
        CurrencyWallet wallet = getOrCreateWallet(req.getUserId());
        wallet.addCoins(coins);
        wallet.addGems(gems);
        wallet.setLastUpdated(LocalDateTime.now());
        walletRepo.save(wallet);

        // Record transaction
        RewardTransaction txn = new RewardTransaction();
        txn.setUserId(req.getUserId());
        txn.setMatchId(req.getMatchId());
        txn.setCoinsEarned(coins);
        txn.setGemsEarned(gems);
        txn.setReason("MATCH_REWARD");
        txn.setCreatedAt(LocalDateTime.now());
        txnRepo.save(txn);

        RewardResultDto dto = new RewardResultDto();
        dto.setUserId(req.getUserId());
        dto.setMatchId(req.getMatchId());
        dto.setCoinsEarned(coins);
        dto.setGemsEarned(gems);
        dto.setReason("MATCH_REWARD");
        dto.setTotalCoins(wallet.getCoins());
        dto.setTotalGems(wallet.getGems());
        dto.setAlreadyRewarded(false);
        return dto;
    }

    /** Spend coins (e.g. for cosmetic purchase). Throws 400 if insufficient. */
    @Transactional
    public WalletDto spendCoins(Long userId, int amount) {
        CurrencyWallet wallet = getOrCreateWallet(userId);
        if (!wallet.spendCoins(amount)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Insufficient coins");
        }
        wallet.setLastUpdated(LocalDateTime.now());
        walletRepo.save(wallet);
        return toDto(wallet);
    }

    /** Spend gems. Throws 400 if insufficient. */
    @Transactional
    public WalletDto spendGems(Long userId, int amount) {
        CurrencyWallet wallet = getOrCreateWallet(userId);
        if (!wallet.spendGems(amount)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Insufficient gems");
        }
        wallet.setLastUpdated(LocalDateTime.now());
        walletRepo.save(wallet);
        return toDto(wallet);
    }

    // ─── helpers ──────────────────────────────────────────────

    CurrencyWallet getOrCreateWallet(Long userId) {
        Optional<CurrencyWallet> opt = walletRepo.findByUserId(userId);
        if (opt.isPresent()) return opt.get();

        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        CurrencyWallet wallet = new CurrencyWallet();
        wallet.setUser(user);
        wallet.setCoins(0);
        wallet.setGems(0);
        wallet.setLastUpdated(LocalDateTime.now());
        return walletRepo.save(wallet);
    }

    private WalletDto toDto(CurrencyWallet w) {
        WalletDto dto = new WalletDto();
        dto.setUserId(w.getUser().getId());
        dto.setCoins(w.getCoins());
        dto.setGems(w.getGems());
        return dto;
    }
}
