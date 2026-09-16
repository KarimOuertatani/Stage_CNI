package com.fitforge.api.training.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.PositiveOrZero;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Enregistrement d'une seance effectuee (avec ses series).
 * sessionId est optionnel : une seance libre n'est rattachee a aucune
 * seance-type.
 */
@Schema(description = "Enregistrement d'une seance effectuee")
public record CreateWorkoutLogRequest(

        @Schema(description = "Seance-type suivie (optionnel)")
        UUID sessionId,

        @Schema(description = "Date de realisation", example = "2026-07-20")
        @NotNull @PastOrPresent LocalDate performedOn,

        @Schema(example = "65") @PositiveOrZero Integer durationMinutes,

        @Schema(description = "Ressenti d'effort 1..10", example = "8")
        @Min(1) @Max(10) Integer rpe,

        @Schema(description = "Series realisees")
        @Valid List<CreateSetLogRequest> sets
) {}
