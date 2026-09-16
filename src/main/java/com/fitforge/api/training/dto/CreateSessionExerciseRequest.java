package com.fitforge.api.training.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

import java.util.UUID;

/**
 * Donnees pour placer un exercice du referentiel dans une seance,
 * avec ses objectifs (series/reps/poids/repos).
 */
@Schema(description = "Ajout d'un exercice a une seance")
public record CreateSessionExerciseRequest(

        @Schema(description = "Id de l'exercice du referentiel")
        @NotNull UUID exerciseId,

        @Schema(example = "4") @Positive Integer targetSets,
        @Schema(example = "10") @Positive Integer targetReps,
        @Schema(example = "60.0") @PositiveOrZero Double targetWeightKg,
        @Schema(example = "90") @PositiveOrZero Integer restSeconds,
        @Schema(description = "Ordre dans la seance", example = "0") Integer orderIndex
) {}
