package com.fitforge.api.nutrition.ai.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.UUID;

/**
 * Un aliment repere par une analyse automatique — <b>photo de repas</b> ou
 * <b>description vocale</b> — enrichi de ses valeurs nutritionnelles.
 *
 * <p><b>Rien n'est enregistre.</b> C'est une <i>proposition</i> : l'adherent
 * ajuste puis confirme aliment par aliment via {@code POST /nutrition/from-food},
 * qui reste le seul chemin d'ecriture du journal.
 *
 * <p>Les valeurs sont fournies <b>deux fois</b> :
 * <ul>
 *   <li>calculees pour {@code quantityGrams}, pour un affichage immediat ;</li>
 *   <li>ramenees a 100 g, pour que l'application recalcule <b>en direct</b>
 *       quand l'adherent corrige la quantite estimee — sans rappeler le
 *       serveur. Le calcul definitif reste fait par le serveur a la
 *       confirmation, source de verite unique.</li>
 * </ul>
 */
@Schema(description = "Aliment repere par une analyse automatique, avec ses macros estimees")
public record AnalyzedFoodDto(

        @Schema(description = "Nom compris par le modele (sur la photo ou dans la phrase)",
                example = "blanc de poulet")
        String detectedLabel,

        @Schema(description = "Quantite estimee en grammes", example = "150")
        double quantityGrams,

        @Schema(description = "Confiance du modele sur l'identification, entre 0 et 1",
                example = "0.82")
        Double confidence,

        @Schema(description = "Vrai si l'aliment a ete retrouve dans le catalogue. "
                + "Faux : les macros sont nulles et l'aliment ne peut pas etre ajoute "
                + "directement (saisie manuelle).")
        boolean matched,

        @Schema(description = "Libelle de l'aliment retrouve au catalogue",
                example = "Poulet, de chair, blanc, viande seule, cru")
        String foodName,

        @Schema(description = "Id catalogue local — a renvoyer a /from-food si present")
        UUID foodItemId,

        @Schema(description = "Id USDA — a renvoyer a /from-food si foodItemId est absent")
        Long fdcId,

        @Schema(description = "Code-barres Open Food Facts — a renvoyer a /from-food "
                + "si c'est cette source qui a fourni l'aliment")
        String offCode,

        // ── Valeurs pour la quantite estimee ──────────────────────────

        @Schema(description = "Calories pour la quantite estimee", example = "165")
        Integer calories,

        @Schema(description = "Proteines (g) pour la quantite estimee", example = "31.0")
        Double proteinG,

        @Schema(description = "Glucides (g) pour la quantite estimee", example = "0.0")
        Double carbsG,

        @Schema(description = "Lipides (g) pour la quantite estimee", example = "3.6")
        Double fatG,

        @Schema(description = "Fibres (g) pour la quantite estimee")
        Double fiberG,

        // ── Valeurs de reference pour 100 g ───────────────────────────

        @Schema(description = "Calories pour 100 g")
        Double caloriesPer100g,

        @Schema(description = "Proteines pour 100 g")
        Double proteinPer100g,

        @Schema(description = "Glucides pour 100 g")
        Double carbsPer100g,

        @Schema(description = "Lipides pour 100 g")
        Double fatPer100g,

        @Schema(description = "Fibres pour 100 g")
        Double fiberPer100g
) {
}
