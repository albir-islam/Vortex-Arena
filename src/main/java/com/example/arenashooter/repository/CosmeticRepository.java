package com.example.arenashooter.repository;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import com.example.arenashooter.entity.Cosmetic;

@Repository
public interface CosmeticRepository extends JpaRepository<Cosmetic, Long> {
    List<Cosmetic> findByType(String type);
}
