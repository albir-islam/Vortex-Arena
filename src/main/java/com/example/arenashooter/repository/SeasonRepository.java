package com.example.arenashooter.repository;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import com.example.arenashooter.entity.Season;

@Repository
public interface SeasonRepository extends JpaRepository<Season, Long> {
    Optional<Season> findByActiveTrue();
}
