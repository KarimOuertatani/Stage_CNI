package com.fitforge.api.admin.dto;

import com.fitforge.api.common.enums.ProblemStatus;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Traitement d'un signalement par l'administration.
 *
 * <h2>Pourquoi {@code response} est facultatif ici, alors que le motif de refus
 * d'un coach est obligatoire</h2>
 * Les deux situations n'ont pas la meme consequence. Refuser un coach sans motif
 * le laisse sans rien a corriger : le refus devient inexploitable. Passer un
 * signalement en « pris en charge » est en revanche une information suffisante
 * en soi -- exiger un texte a cette etape pousserait a ecrire « ok » pour
 * satisfaire le formulaire.
 *
 * <p>La contrainte utile est ailleurs, et elle est portee par le service :
 * <b>cloturer</b> un signalement (RESOLVED ou CLOSED) exige une reponse. C'est
 * la que l'auteur attend un retour, et c'est le seul moment ou il en recevra un.
 */
@Schema(description = "Decision de l'administrateur sur un signalement")
public record HandleProblemReportRequest(

        @NotNull(message = "Le nouveau statut est obligatoire")
        ProblemStatus status,

        @Size(max = 2000, message = "La reponse ne peut pas depasser 2000 caracteres")
        @Schema(description = "Reponse affichee a l'auteur. Obligatoire pour RESOLVED et CLOSED.",
                example = "Corrige dans la version 1.1 : le minuteur repart bien apres une mise en pause.")
        String response
) {}
