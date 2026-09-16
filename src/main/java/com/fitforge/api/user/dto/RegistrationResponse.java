package com.fitforge.api.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * Reponse a une inscription.
 *
 * <p><b>Aucun token n'est renvoye ici</b> — contrairement a l'ancien
 * comportement d'auto-connexion. Le compte est cree {@code enabled = false} et
 * le client doit d'abord valider le code recu par email
 * ({@code POST /auth/verify-email}), qui renvoie alors le JWT.
 */
@Schema(description = "Inscription enregistree, en attente de verification par email")
public record RegistrationResponse(

        @Schema(description = "Adresse a verifier", example = "sami@fitforge.tn")
        String email,

        @Schema(description = "Duree de validite du code en minutes", example = "10")
        int expiresInMinutes,

        @Schema(description = "Message a afficher a l'utilisateur")
        String message
) {
}
