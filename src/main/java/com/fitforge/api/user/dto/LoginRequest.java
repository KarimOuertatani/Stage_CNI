package com.fitforge.api.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/**
 * Identifiants envoyes par Flutter pour se connecter.
 */
@Schema(description = "Requete de connexion")
public record LoginRequest(

        @Schema(description = "Email du compte", example = "sami@fitforge.tn")
        @NotBlank @Email
        String email,

        @Schema(description = "Mot de passe", example = "MonMotDePasse123")
        @NotBlank
        String password
) {}
