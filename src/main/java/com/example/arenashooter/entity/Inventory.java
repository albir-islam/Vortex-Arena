package com.example.arenashooter.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "inventory")
public class Inventory {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(name = "primary_weapon")
    private String primaryWeapon;

    @Column(name = "secondary_weapon")
    private String secondaryWeapon;

    @Column(name = "first_aid_count")
    private int firstAidCount;

    @Column(name = "medkit_count")
    private int medkitCount;

    @Column(name = "boost_count")
    private int boostCount;

    @Column(name = "helmet_level")
    private int helmetLevel;

    @Column(name = "vest_level")
    private int vestLevel;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public User getUser() {
        return user;
    }

    public void setUser(User user) {
        this.user = user;
    }

    public String getPrimaryWeapon() {
        return primaryWeapon;
    }

    public void setPrimaryWeapon(String primaryWeapon) {
        this.primaryWeapon = primaryWeapon;
    }

    public String getSecondaryWeapon() {
        return secondaryWeapon;
    }

    public void setSecondaryWeapon(String secondaryWeapon) {
        this.secondaryWeapon = secondaryWeapon;
    }

    public int getFirstAidCount() {
        return firstAidCount;
    }

    public void setFirstAidCount(int firstAidCount) {
        this.firstAidCount = firstAidCount;
    }

    public int getMedkitCount() {
        return medkitCount;
    }

    public void setMedkitCount(int medkitCount) {
        this.medkitCount = medkitCount;
    }

    public int getBoostCount() {
        return boostCount;
    }

    public void setBoostCount(int boostCount) {
        this.boostCount = boostCount;
    }

    public int getHelmetLevel() {
        return helmetLevel;
    }

    public void setHelmetLevel(int helmetLevel) {
        this.helmetLevel = helmetLevel;
    }

    public int getVestLevel() {
        return vestLevel;
    }

    public void setVestLevel(int vestLevel) {
        this.vestLevel = vestLevel;
    }
}
