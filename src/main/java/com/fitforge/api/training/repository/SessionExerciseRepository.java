package com.fitforge.api.training.repository;

import com.fitforge.api.training.entity.SessionExercise;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

/**
 * Acces base pour les exercices places dans une seance.
 */
public interface SessionExerciseRepository extends JpaRepository<SessionExercise, UUID> {
}
