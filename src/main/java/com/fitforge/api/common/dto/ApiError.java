package com.fitforge.api.common.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;

/**
 * Forme unique des erreurs renvoyees par l'API (JSON), pour que Flutter
 * puisse toujours lire status/code/message de la meme facon.
 *
 * @param status    code HTTP (404, 400...)
 * @param code      code applicatif court (NOT_FOUND, VALIDATION_ERROR...)
 * @param message   message lisible expliquant l'erreur
 * @param timestamp instant de l'erreur (UTC)
 */
@Schema(description = "Erreur standardisee renvoyee par l'API")
public record ApiError(
        @Schema(description = "Code HTTP", example = "404")
        int status,

        @Schema(description = "Code applicatif court", example = "NOT_FOUND")
        String code,

        @Schema(description = "Message lisible", example = "Profil introuvable")
        String message,

        @Schema(description = "Instant de l'erreur (UTC)")
        Instant timestamp
) {
    /** Fabrique pratique qui date automatiquement l'erreur a maintenant. */
    public static ApiError of(int status, String code, String message) {
        return new ApiError(status, code, message, Instant.now());
    }
}
