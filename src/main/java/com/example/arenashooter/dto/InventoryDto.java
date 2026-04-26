package com.example.arenashooter.dto;

public class InventoryDto {
    private String primaryWeapon;
    private String secondaryWeapon;
    private int firstAidCount;
    private int medkitCount;
    private int boostCount;
    private int helmetLevel;
    private int vestLevel;

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
