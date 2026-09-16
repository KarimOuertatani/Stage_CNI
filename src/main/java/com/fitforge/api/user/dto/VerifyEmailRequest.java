package com.fitforge.api.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * Validation du code recu par email.
 */
@Schema(description = "Verification de l'adresse email par code a 6 chiffres")
public record VerifyEmailRequest(

        @Schema(description = "Adresse du compte", example = "sami@fitforge.tn")
        @NotBlank(message = "l'email est obligatoire")
        @Email(message = "format d'email invalide")
        String email,

        @Schema(description = "Code a 6 chiffres recu par email", example = "482915")
        @NotBlank(message = "le code est obligatoire")
        @Pattern(regexp = "\\d{6}", message = "le code doit contenir exactement 6 chiffres")
        String code
) {
}
