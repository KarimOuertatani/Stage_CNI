package com.fitforge.api.score.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.util.UUID;

/**
 * Score d'entrainement renvoye a Flutter.
 */
@Schema(description = "Score d'entrainement hebdomadaire")
public record TrainingScoreResponse(
        UUID id,
        @Schema(description = "Lundi de la semaine calculee") LocalDate scoreDate,
        @Schema(description = "Note 0..100", example = "82") Integer score,
        @Schema(description = "Volume total souleve (kg)", example = "12500.0") Double weeklyVolumeKg,
        @Schema(description = "Seances de la semaine", example = "4") Integer sessionsCompleted,
        @Schema(description = "Assiduite vs objectif (0..1)", example = "1.0") Double consistencyRate,
        @Schema(description = "Analyse", example = "Volume en hausse de 8%. Objectif hebdo atteint !")
        String insight
) {}
