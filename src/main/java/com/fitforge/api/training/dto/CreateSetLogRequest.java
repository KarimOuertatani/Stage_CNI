package com.fitforge.api.training.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

import java.util.UUID;

/**
 * Une serie realisee, envoyee dans le cadre d'une seance effectuee.
 */
@Schema(description = "Serie realisee")
public record CreateSetLogRequest(

        @Schema(description = "Id de l'exercice realise")
        @NotNull UUID exerciseId,

        @Schema(example = "1") @Positive Integer setNumber,
        @Schema(example = "10") @PositiveOrZero Integer reps,
        @Schema(example = "60.0") @PositiveOrZero Double weightKg,
        @Schema(example = "true") boolean completed
) {}
