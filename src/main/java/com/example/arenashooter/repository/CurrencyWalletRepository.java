package com.example.arenashooter.repository;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import com.example.arenashooter.entity.CurrencyWallet;

@Repository
public interface CurrencyWalletRepository extends JpaRepository<CurrencyWallet, Long> {
    Optional<CurrencyWallet> findByUserId(Long userId);
}
