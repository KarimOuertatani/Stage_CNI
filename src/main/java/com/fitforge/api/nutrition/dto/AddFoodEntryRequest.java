package com.fitforge.api.nutrition.dto;

import com.fitforge.api.common.enums.MealType;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.util.UUID;

/**
 * Ajout d'un aliment au journal <b>depuis le catalogue</b> : l'adherent ne
 * saisit qu'une <b>quantite en grammes</b>, le serveur calcule les macros.
 *
 * <p>Fournir <b>l'un</b> de ces trois identifiants, celui que la recherche a
 * renvoye pour cet aliment :
 * <ul>
 *   <li>{@code foodItemId} — aliment deja en catalogue ;</li>
 *   <li>{@code fdcId} — aliment USDA, importe et mis en cache au passage ;</li>
 *   <li>{@code offCode} — produit Open Food Facts (code-barres), importe et
 *       mis en cache au passage.</li>
 * </ul>
 * En cas de doublon, l'ordre de priorite est celui de cette liste.
 */
@Schema(description = "Ajout d'un aliment du catalogue au journal alimentaire")
public record AddFoodEntryRequest(

        @Schema(description = "Id de l'aliment dans notre catalogue local")
        UUID foodItemId,

        @Schema(description = "Id USDA FoodData Central", example = "171077")
        Long fdcId,

        @Schema(description = "Code-barres Open Food Facts", example = "3033710065967")
        @Size(max = 64, message = "code produit invalide")
        String offCode,

        @Schema(description = "Jour de consommation", example = "2026-07-28")
        @NotNull(message = "la date de consommation est obligatoire")
        LocalDate consumedOn,

        @Schema(description = "Repas", example = "DEJEUNER")
        @NotNull(message = "le type de repas est obligatoire")
        MealType mealType,

        @Schema(description = "Quantite consommee en grammes", example = "150")
        @NotNull(message = "la quantite est obligatoire")
        @Positive(message = "la quantite doit etre superieure a 0")
        @DecimalMax(value = "5000", message = "la quantite ne peut pas depasser 5000 g")
        Double quantityGrams
) {

    /** Vrai si la requete designe bien un aliment (l'un des trois identifiants). */
    public boolean hasFoodReference() {
        return foodItemId != null || fdcId != null || (offCode != null && !offCode.isBlank());
    }
}
