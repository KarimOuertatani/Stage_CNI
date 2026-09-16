package com.fitforge.api.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/**
 * Demande d'un nouveau code de verification (au plus un par minute).
 */
@Schema(description = "Demande de renvoi du code de verification")
public record ResendCodeRequest(

        @Schema(description = "Adresse du compte a verifier", example = "sami@fitforge.tn")
        @NotBlank(message = "l'email est obligatoire")
        @Email(message = "format d'email invalide")
        String email
) {
}
