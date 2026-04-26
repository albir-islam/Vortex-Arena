package com.example.arenashooter.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "currency_wallet")
public class CurrencyWallet {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "wallet_id")
    private Long walletId;

    @OneToOne
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(nullable = false)
    private int coins = 0;

    @Column(nullable = false)
    private int gems = 0;

    @Column(name = "last_updated")
    private LocalDateTime lastUpdated = LocalDateTime.now();

    public Long getWalletId() { return walletId; }
    public void setWalletId(Long walletId) { this.walletId = walletId; }

    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }

    public int getCoins() { return coins; }
    public void setCoins(int coins) { this.coins = coins; }

    public int getGems() { return gems; }
    public void setGems(int gems) { this.gems = gems; }

    public LocalDateTime getLastUpdated() { return lastUpdated; }
    public void setLastUpdated(LocalDateTime lastUpdated) { this.lastUpdated = lastUpdated; }

    public void addCoins(int amount) {
        this.coins += amount;
        this.lastUpdated = LocalDateTime.now();
    }

    public void addGems(int amount) {
        this.gems += amount;
        this.lastUpdated = LocalDateTime.now();
    }

    public boolean spendCoins(int amount) {
        if (this.coins < amount) return false;
        this.coins -= amount;
        this.lastUpdated = LocalDateTime.now();
        return true;
    }

    public boolean spendGems(int amount) {
        if (this.gems < amount) return false;
        this.gems -= amount;
        this.lastUpdated = LocalDateTime.now();
        return true;
    }
}
