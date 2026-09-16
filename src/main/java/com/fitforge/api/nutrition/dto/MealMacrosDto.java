package com.fitforge.api.nutrition.dto;

import com.fitforge.api.common.enums.MealType;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;

/**
 * Totaux calcules d'un repas (un {@link MealType} d'une journee donnee) :
 * somme des macros de toutes les entrees de ce repas.
 *
 * <p>Un « repas » n'est pas une table dediee : c'est le regroupement naturel
 * {@code (adherent, date, mealType)} des lignes du journal.
 */
@Schema(description = "Totaux calories/macros d'un repas de la journee")
public record MealMacrosDto(

        @Schema(description = "Jour concerne", example = "2026-07-28")
        LocalDate date,

        @Schema(description = "Repas concerne", example = "DEJEUNER")
        MealType mealType,

        @Schema(description = "Nombre d'aliments dans ce repas", example = "3")
        int itemCount,

        @Schema(description = "Calories totales (kcal)", example = "742")
        int totalCalories,

        @Schema(description = "Proteines totales (g)", example = "48.5")
        double totalProteinG,

        @Schema(description = "Glucides totaux (g)", example = "62.1")
        double totalCarbsG,

        @Schema(description = "Lipides totaux (g)", example = "28.4")
        double totalFatG,

        @Schema(description = "Fibres totales (g)", example = "7.2")
        double totalFiberG
) {
}
