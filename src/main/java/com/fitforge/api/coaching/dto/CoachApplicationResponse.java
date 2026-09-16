package com.fitforge.api.coaching.dto;

import com.fitforge.api.common.enums.CoachStatus;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.List;

/**
 * Etat de la candidature du coach connecte : ce que l'application mobile
 * affiche sur l'ecran « Ma candidature ».
 *
 * <p>{@code missingRequirements} est le champ qui fait travailler l'ecran a la
 * place du coach. Sans lui, l'application devrait redupliquer la regle de
 * completude cote client -- et les deux divergeraient : le bouton
 * « Soumettre » paraitrait actif, le serveur refuserait, et le coach n'aurait
 * aucun moyen de comprendre pourquoi. La regle vit a un seul endroit, le
 * serveur, et voyage sous forme de phrases directement affichables.
 */
@Schema(description = "Etat de la candidature du coach connecte")
public record CoachApplicationResponse(
        CoachStatus status,

        @Schema(description = "Date de soumission du dossier ; null tant qu'il est en brouillon")
        Instant submittedAt,

        @Schema(description = "Date de la decision de l'administration")
        Instant reviewedAt,

        @Schema(description = "Motif du refus, affiche tel quel au coach")
        String rejectionReason,

        List<CoachDocumentResponse> documents,

        @Schema(description = "Ce qu'il manque pour pouvoir soumettre, en phrases affichables",
                example = "[\"Ajoute une photo de ta piece d'identite\"]")
        List<String> missingRequirements,

        @Schema(description = "Vrai si le dossier peut etre soumis en l'etat")
        boolean canSubmit
) {}
