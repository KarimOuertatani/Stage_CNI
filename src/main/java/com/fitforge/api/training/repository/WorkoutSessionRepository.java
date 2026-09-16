package com.fitforge.api.training.repository;

import com.fitforge.api.training.entity.WorkoutSession;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

/**
 * Acces base pour les seances-types.
 */
public interface WorkoutSessionRepository extends JpaRepository<WorkoutSession, UUID> {
}
