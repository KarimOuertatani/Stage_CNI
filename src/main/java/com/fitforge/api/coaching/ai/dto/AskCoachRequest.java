package com.fitforge.api.coaching.ai.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Une question posee au coach IA.
 *
 * <p>La borne haute n'est pas cosmetique : chaque message part au modele avec
 * l'historique, et le cout comme la latence croissent avec la taille. 1000
 * caracteres laissent tres largement la place a une question de sport — au-dela,
 * il s'agit d'un texte colle, pas d'une question.
 */
@Schema(description = "Question posee au coach IA")
public record AskCoachRequest(

        @Schema(description = "La question, en francais",
                example = "Combien de series pour prendre du muscle aux pectoraux ?")
        @NotBlank(message = "ecrivez votre question")
        @Size(min = 2, max = 1000,
                message = "la question doit faire entre 2 et 1000 caracteres")
        String text
) {
}
