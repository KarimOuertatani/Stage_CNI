package com.fitforge.api.nutrition.vision.dto;

import com.fitforge.api.nutrition.ai.dto.AnalyzedFoodDto;
import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

/**
 * Resultat de l'analyse d'une photo de repas.
 *
 * <p><b>Aucune ecriture en base.</b> Cette reponse est une proposition que
 * l'adherent valide ensuite aliment par aliment via
 * {@code POST /nutrition/from-food}.
 *
 * <p>Les totaux ne comptent que les aliments <b>retrouves au catalogue</b>
 * ({@code matched = true}) : additionner des macros inconnues donnerait un
 * total faussement rassurant.
 */
@Schema(description = "Proposition issue de l'analyse d'une photo de repas")
public record PhotoAnalysisResponse(

        @Schema(description = "Aliments detectes, dans l'ordre renvoye par le modele")
        List<AnalyzedFoodDto> foods,

        @Schema(description = "Nombre d'aliments detectes sur la photo", example = "4")
        int detectedCount,

        @Schema(description = "Nombre d'aliments effectivement retrouves au catalogue",
                example = "3")
        int matchedCount,

        @Schema(description = "Calories totales des aliments retrouves", example = "612")
        int totalCalories,

        @Schema(description = "Proteines totales (g)", example = "44.2")
        double totalProteinG,

        @Schema(description = "Glucides totaux (g)", example = "58.1")
        double totalCarbsG,

        @Schema(description = "Lipides totaux (g)", example = "19.4")
        double totalFatG,

        @Schema(description = "Fibres totales (g)", example = "6.3")
        double totalFiberG
) {

    /** Reponse d'une photo sans aucun aliment reconnaissable. */
    public static PhotoAnalysisResponse empty() {
        return new PhotoAnalysisResponse(List.of(), 0, 0, 0, 0, 0, 0, 0);
    }
}
