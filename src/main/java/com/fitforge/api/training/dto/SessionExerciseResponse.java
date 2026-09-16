package com.fitforge.api.training.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.UUID;

/**
 * Exercice place dans une seance, renvoye avec le detail de l'exercice.
 */
@Schema(description = "Exercice place dans une seance (avec objectifs)")
public record SessionExerciseResponse(
        UUID id,
        ExerciseResponse exercise,
        Integer targetSets,
        Integer targetReps,
        Double targetWeightKg,
        Integer restSeconds,
        Integer orderIndex,

        @Schema(description = "Consigne d'execution pour cet exercice dans cette seance "
                + "(tempo, repetitions en reserve, adaptation). Null si aucune.",
                example = "Descends en 3 secondes, garde 2 repetitions en reserve.")
        String notes
) {}
