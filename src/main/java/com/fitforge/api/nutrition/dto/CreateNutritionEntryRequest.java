package com.fitforge.api.nutrition.dto;

import com.fitforge.api.common.enums.MealType;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

import java.time.LocalDate;

/**
 * Donnees pour ajouter ou modifier une entree du journal alimentaire
 * <b>en saisie manuelle</b> (repas maison, restaurant, produit absent de la
 * base USDA).
 *
 * <p>Pour ajouter un aliment du catalogue avec macros calculees
 * automatiquement, utiliser {@link AddFoodEntryRequest} et
 * {@code POST /nutrition/from-food}.
 */
@Schema(description = "Ajout/modification manuelle d'un aliment ou repas")
public record CreateNutritionEntryRequest(

        @Schema(example = "2026-07-20")
        @NotNull LocalDate consumedOn,

        @NotNull MealType mealType,

        @Schema(example = "Poulet grille")
        @NotBlank String foodName,

        @Schema(example = "150.0") @PositiveOrZero Double quantityGrams,
        @Schema(example = "250") @PositiveOrZero Integer calories,
        @Schema(example = "30.0") @PositiveOrZero Double proteinG,
        @Schema(example = "0.0") @PositiveOrZero Double carbsG,
        @Schema(example = "12.0") @PositiveOrZero Double fatG,
        @Schema(example = "2.5") @PositiveOrZero Double fiberG
) {}
