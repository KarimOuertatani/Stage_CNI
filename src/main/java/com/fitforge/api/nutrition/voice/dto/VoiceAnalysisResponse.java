package com.fitforge.api.nutrition.voice.dto;

import com.fitforge.api.nutrition.ai.dto.AnalyzedFoodDto;
import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

/**
 * Resultat d'un ajout de repas <b>a la voix</b> (ou par une phrase ecrite).
 *
 * <p><b>Aucune ecriture en base.</b> Comme pour la photo, cette reponse est une
 * proposition que l'adherent valide ensuite aliment par aliment via
 * {@code POST /nutrition/from-food}.
 *
 * <p>Les totaux ne comptent que les aliments <b>retrouves au catalogue</b>
 * ({@code matched = true}) : additionner des macros inconnues donnerait un
 * total faussement rassurant.
 */
@Schema(description = "Proposition issue d'une description vocale ou ecrite d'un repas")
public record VoiceAnalysisResponse(

        @Schema(description = "Ce que le modele a compris, mot pour mot. Affiche a "
                + "l'adherent pour qu'il puisse corriger un mot mal entendu et "
                + "relancer l'analyse en mode texte.",
                example = "Ce midi j'ai mange deux oeufs et une tranche de pain complet")
        String transcript,

        @Schema(description = "Aliments compris, dans l'ordre ou ils ont ete cites")
        List<AnalyzedFoodDto> foods,

        @Schema(description = "Nombre d'aliments compris", example = "3")
        int detectedCount,

        @Schema(description = "Nombre d'aliments effectivement retrouves au catalogue",
                example = "3")
        int matchedCount,

        @Schema(description = "Calories totales des aliments retrouves", example = "412")
        int totalCalories,

        @Schema(description = "Proteines totales (g)", example = "24.2")
        double totalProteinG,

        @Schema(description = "Glucides totaux (g)", example = "38.1")
        double totalCarbsG,

        @Schema(description = "Lipides totaux (g)", example = "14.4")
        double totalFatG,

        @Schema(description = "Fibres totales (g)", example = "3.3")
        double totalFiberG
) {

    /**
     * Reponse d'un enregistrement ou d'une phrase ou aucun aliment n'a ete
     * compris. La transcription est conservee : elle explique a l'adherent
     * <i>pourquoi</i> rien n'a ete trouve, et lui permet de la corriger.
     */
    public static VoiceAnalysisResponse empty(String transcript) {
        return new VoiceAnalysisResponse(transcript, List.of(), 0, 0, 0, 0, 0, 0, 0);
    }
}
