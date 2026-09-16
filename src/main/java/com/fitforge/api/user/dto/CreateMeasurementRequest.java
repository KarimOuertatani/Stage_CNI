package com.fitforge.api.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Positive;

import java.time.LocalDate;

/**
 * Donnees d'une nouvelle pesee/mensuration a ajouter a l'historique.
 */
@Schema(description = "Ajout d'une pesee/mensuration")
public record CreateMeasurementRequest(

        @Schema(description = "Date de la pesee", example = "2026-07-20")
        @NotNull @PastOrPresent LocalDate measuredOn,

        @Schema(example = "74.5") @Positive Double weightKg,
        @Schema(example = "15.2") @Positive Double bodyFatPercent,
        @Schema(example = "82.0") @Positive Double waistCm,
        @Schema(example = "100.0") @Positive Double chestCm,
        @Schema(example = "36.0") @Positive Double armCm,
        @Schema(example = "58.0") @Positive Double thighCm
) {}
