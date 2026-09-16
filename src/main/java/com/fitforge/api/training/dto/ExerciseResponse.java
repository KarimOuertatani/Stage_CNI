package com.fitforge.api.training.dto;

import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.common.enums.ExperienceLevel;
import com.fitforge.api.common.enums.MuscleGroup;
import io.swagger.v3.oas.annotations.media.Schema;

import java.util.UUID;

/**
 * Exercice du referentiel renvoye a Flutter.
 *
 * <p>Enrichi avec les donnees ExerciseDB V2 (video, images, instructions,
 * conseils, variations). Les champs restent null pour les exercices seed.
 * Les listes n'affichent que {@code imageUrl}/{@code imageUrl360p} (perf) ;
 * l'ecran de detail utilise {@code videoUrl} et {@code imageUrl720p}.
 */
@Schema(description = "Exercice du referentiel (avec media et contenu pedagogique)")
public record ExerciseResponse(
        UUID id,
        String name,
        MuscleGroup primaryMuscle,
        Equipment equipment,
        /** Niveau requis, calcule une fois cote serveur (voir ExerciseDifficultyRules). */
        ExperienceLevel difficulty,
        String instructions,
        String videoUrl,
        // ── Metadonnees ExerciseDB (brutes, anglais) ──
        String bodyPart,
        String exerciseType,
        String targetMuscles,
        String secondaryMuscles,
        String keywords,
        // ── Contenu pedagogique ──
        String overview,
        String exerciseTips,
        String variations,
        // ── Images multi-resolutions ──
        String imageUrl,
        String imageUrl360p,
        String imageUrl720p
) {}
