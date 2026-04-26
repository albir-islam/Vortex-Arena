package com.example.arenashooter.dto;

public class CosmeticDto {
    private Long cosmeticId;
    private String name;
    private String type;
    private int price;
    private String assetPath;
    private boolean owned;
    private boolean equipped;

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

    public boolean isOwned() { return owned; }
    public void setOwned(boolean owned) { this.owned = owned; }

    public boolean isEquipped() { return equipped; }
    public void setEquipped(boolean equipped) { this.equipped = equipped; }
}
