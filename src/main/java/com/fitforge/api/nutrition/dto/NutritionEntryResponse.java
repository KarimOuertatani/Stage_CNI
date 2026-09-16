package com.fitforge.api.nutrition.dto;

import com.fitforge.api.common.enums.MealType;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.util.UUID;

/**
 * Une entree du journal alimentaire renvoyee a Flutter.
 *
 * <p>{@code foodItemId} identifie l'aliment du catalogue dont l'entree provient.
 * Il vaut {@code null} pour une saisie manuelle : l'app s'en sert pour savoir
 * si la quantite est modifiable (recalcul automatique des macros) ou si toutes
 * les valeurs doivent etre re-saisies.
 */
@Schema(description = "Entree du journal alimentaire")
public record NutritionEntryResponse(
        UUID id,
        LocalDate consumedOn,
        MealType mealType,

        @Schema(description = "Aliment du catalogue source (null = saisie manuelle)")
        UUID foodItemId,

        String foodName,

        @Schema(description = "Quantite consommee en grammes", example = "150.0")
        Double quantityGrams,

        Integer calories,
        Double proteinG,
        Double carbsG,
        Double fatG,

        @Schema(description = "Fibres (g)", example = "2.5")
        Double fiberG
) {}
