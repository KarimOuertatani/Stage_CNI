package com.fitforge.api.training.repository;

import com.fitforge.api.training.entity.WorkoutLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Acces base pour les seances effectuees.
 */
public interface WorkoutLogRepository extends JpaRepository<WorkoutLog, UUID> {

    /** Seances d'un adherent sur une periode [from, to], recentes d'abord. */
    List<WorkoutLog> findByUserIdAndPerformedOnBetweenOrderByPerformedOnDesc(
            UUID userId, LocalDate from, LocalDate to);
}
