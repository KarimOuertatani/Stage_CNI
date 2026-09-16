package com.fitforge.api.nutrition.dto;

import com.fitforge.api.common.enums.FoodResultSource;
import io.swagger.v3.oas.annotations.media.Schema;

import java.util.UUID;

/**
 * Aliment propose par la recherche — reponse <b>epuree</b> renvoyee au client.
 *
 * <p>Les valeurs sont exprimees <b>pour 100 g</b> : c'est l'app qui affiche
 * l'apercu, et le <b>serveur</b> qui recalcule au prorata a l'enregistrement
 * (source de verite unique).
 *
 * <p>Un resultat porte <b>exactement un</b> identifiant, selon la source qui
 * l'a fourni :
 * <ul>
 *   <li>{@code foodItemId} : l'aliment est deja dans notre catalogue local
 *       (ajout instantane, aucun appel externe) ;</li>
 *   <li>{@code fdcId} : l'aliment vient de USDA et sera mis en cache au
 *       premier ajout ;</li>
 *   <li>{@code offCode} : l'aliment vient d'Open Food Facts (code-barres) et
 *       sera mis en cache au premier ajout.</li>
 * </ul>
 * L'app renvoie tel quel celui qu'elle a recu a
 * {@code POST /nutrition/from-food}.
 */
@Schema(description = "Aliment trouve par la recherche (valeurs pour 100 g)")
public record FoodSearchResultDto(

        @Schema(description = "Id dans notre catalogue local (null si pas encore importe)")
        UUID foodItemId,

        @Schema(description = "Id USDA FoodData Central (null si l'aliment ne vient pas d'USDA)",
                example = "171077")
        Long fdcId,

        @Schema(description = "Code-barres Open Food Facts (null si l'aliment n'en vient pas)",
                example = "3033710065967")
        String offCode,

        @Schema(description = "Libelle de l'aliment, en francais",
                example = "Oeuf, entier, cru, frais")
        String name,

        @Schema(description = "Marque (produits de marque uniquement)")
        String brand,

        @Schema(description = "Jeu de donnees USDA", example = "SR Legacy")
        String dataType,

        @Schema(description = "Source qui a fourni ce resultat : LOCAL (deja en cache, "
                + "ajout sans appel externe), USDA, ou OPEN_FOOD_FACTS",
                example = "USDA")
        FoodResultSource source,

        @Schema(description = "Deja present dans notre catalogue (ajout sans appel externe). "
                + "Equivalent a source = LOCAL, conserve pour compatibilite de l'app.")
        boolean cached,

        @Schema(description = "Calories pour 100 g", example = "143.0")
        Double caloriesPer100g,

        @Schema(description = "Proteines pour 100 g (g)", example = "12.6")
        Double proteinPer100g,

        @Schema(description = "Glucides pour 100 g (g)", example = "0.72")
        Double carbsPer100g,

        @Schema(description = "Lipides pour 100 g (g)", example = "9.51")
        Double fatPer100g,

        @Schema(description = "Fibres pour 100 g (g) - souvent absentes cote USDA")
        Double fiberPer100g
) {
}
