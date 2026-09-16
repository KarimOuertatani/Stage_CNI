package com.fitforge.api.training.repository;

import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.common.enums.ExperienceLevel;
import com.fitforge.api.common.enums.MuscleGroup;
import com.fitforge.api.training.entity.Exercise;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Acces base pour le referentiel d'exercices.
 */
public interface ExerciseRepository extends JpaRepository<Exercise, UUID> {

    /**
     * Recherche filtree optionnelle : si un parametre est null, il est ignore.
     * Permet un seul endpoint GET /exercises?muscle=&equipment=&bodyPart=&level=&q=.
     *
     * <p>{@code q} doit arriver DEJA en minuscules et DEJA encadre de {@code %}
     * (voir {@code ExerciseService.search}) : construire le motif dans la requete
     * empecherait Hibernate de la mettre en cache et melangerait deux
     * responsabilites — la normalisation du texte saisi appartient au service.
     *
     * <p>Le texte est cherche dans le nom, mais aussi dans les mots-cles et les
     * muscles cibles fournis par ExerciseDB : c'est ce qui fait qu'une recherche
     * « triceps » remonte le « Close Grip Bench Press », dont le nom ne contient
     * pourtant pas le mot.
     */
    @Query("""
            SELECT e FROM Exercise e
            WHERE (:muscle IS NULL OR e.primaryMuscle = :muscle)
              AND (:equipment IS NULL OR e.equipment = :equipment)
              AND (:bodyPart IS NULL OR e.bodyPart = :bodyPart)
              AND (:level IS NULL OR e.difficulty = :level)
              AND (:q IS NULL
                   OR LOWER(e.name) LIKE :q
                   OR LOWER(COALESCE(e.keywords, '')) LIKE :q
                   OR LOWER(COALESCE(e.targetMuscles, '')) LIKE :q
                   OR LOWER(COALESCE(e.secondaryMuscles, '')) LIKE :q)
            ORDER BY e.name ASC
            """)
    List<Exercise> search(@Param("muscle") MuscleGroup muscle,
                          @Param("equipment") Equipment equipment,
                          @Param("bodyPart") String bodyPart,
                          @Param("level") ExperienceLevel level,
                          @Param("q") String q);

    /** Exercices dont le niveau n'a pas encore ete calcule (voir le backfill). */
    List<Exercise> findByDifficultyIsNull();

    /**
     * Par partie du corps : nombre d'exercices + une photo representative (une
     * vraie image d'exercice, .jpg) pour illustrer la carte de la zone.
     */
    @Query("""
            SELECT e.bodyPart AS bodyPart, COUNT(e) AS total, MIN(e.imageUrl) AS sampleImage
            FROM Exercise e
            WHERE e.bodyPart IS NOT NULL
            GROUP BY e.bodyPart
            """)
    List<BodyPartCount> countByBodyPart();

    /** Projection {zone -> nombre d'exercices, photo representative}. */
    interface BodyPartCount {
        String getBodyPart();

        long getTotal();

        String getSampleImage();
    }

    /** Vrai si un exercice ExerciseDB de cet identifiant externe existe deja. */
    boolean existsByExternalId(String externalId);

    /** Nombre d'exercices importes d'ExerciseDB (external_id non nul). */
    long countByExternalIdIsNotNull();

    /** Exercices seed (non importes) encore depourvus de video de demonstration. */
    List<Exercise> findByExternalIdIsNullAndVideoUrlIsNull();

    /** Premier exercice importe portant ce nom exact (source de media a copier). */
    Optional<Exercise> findFirstByNameAndExternalIdIsNotNull(String name);
}
