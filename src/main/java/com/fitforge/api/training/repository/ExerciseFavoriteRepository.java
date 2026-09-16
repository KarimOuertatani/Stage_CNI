package com.fitforge.api.training.repository;

import com.fitforge.api.training.entity.Exercise;
import com.fitforge.api.training.entity.ExerciseFavorite;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

/**
 * Acces base aux exercices mis en favori.
 */
public interface ExerciseFavoriteRepository extends JpaRepository<ExerciseFavorite, UUID> {

    /**
     * Les exercices favoris d'un adherent, les plus recemment ajoutes d'abord.
     *
     * <p>On renvoie les {@link Exercise} et non les {@link ExerciseFavorite} :
     * l'ecran affiche des exercices, et passer par les favoris obligerait a
     * traverser une relation LAZY pour chaque ligne (N+1).
     */
    @Query("""
            SELECT f.exercise FROM ExerciseFavorite f
            WHERE f.user.id = :userId
            ORDER BY f.createdAt DESC
            """)
    List<Exercise> findFavoriteExercises(@Param("userId") UUID userId);

    boolean existsByUserIdAndExerciseId(UUID userId, UUID exerciseId);

    void deleteByUserIdAndExerciseId(UUID userId, UUID exerciseId);
}
