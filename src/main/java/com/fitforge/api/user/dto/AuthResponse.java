package com.fitforge.api.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.UUID;

/**
 * Reponse renvoyee apres inscription ou connexion : contient le token JWT
 * que Flutter placera dans l'en-tete {@code Authorization: Bearer <token>}.
 */
@Schema(description = "Reponse d'authentification (token JWT)")
public record AuthResponse(

        @Schema(description = "Token JWT a envoyer sur chaque requete")
        String token,

        @Schema(description = "Type de token", example = "Bearer")
        String tokenType,

        @Schema(description = "Duree de validite du token en millisecondes", example = "86400000")
        long expiresInMs,

        @Schema(description = "Id du compte")
        UUID userId,

        @Schema(description = "Email du compte", example = "sami@fitforge.tn")
        String email,

        @Schema(description = "Nom complet", example = "Sami Ben Ali")
        String fullName
) {}
