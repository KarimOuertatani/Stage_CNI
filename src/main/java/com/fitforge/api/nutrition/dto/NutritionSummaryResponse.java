package com.fitforge.api.nutrition.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;

/**
 * Totaux calories/macros d'une journee (somme des entrees du jour).
 */
@Schema(description = "Totaux nutritionnels d'une journee")
public record NutritionSummaryResponse(
        LocalDate date,
        @Schema(description = "Nombre d'aliments/repas du jour", example = "5")
        int entryCount,
        int totalCalories,
        double totalProteinG,
        double totalCarbsG,
        double totalFatG,

        @Schema(description = "Fibres totales du jour (g)", example = "24.3")
        double totalFiberG
) {}
