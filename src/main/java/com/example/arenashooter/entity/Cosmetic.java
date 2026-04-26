package com.example.arenashooter.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "cosmetics")
public class Cosmetic {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "cosmetic_id")
    private Long cosmeticId;

    @Column(nullable = false, unique = true, length = 100)
    private String name;

    @Column(nullable = false, length = 20)
    private String type = "SKIN";

    @Column(nullable = false)
    private int price = 0;

    @Column(name = "asset_path", nullable = false)
    private String assetPath;

    public Long getCosmeticId() { return cosmeticId; }
    public void setCosmeticId(Long cosmeticId) { this.cosmeticId = cosmeticId; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getType() { return type; }
    public void setType(String type) { this.type = type; }

    public int getPrice() { return price; }
    public void setPrice(int price) { this.price = price; }

    public String getAssetPath() { return assetPath; }
    public void setAssetPath(String assetPath) { this.assetPath = assetPath; }
}
