package com.fitforge.api.admin.dto;

import com.fitforge.api.common.enums.CoachStatus;
import com.fitforge.api.common.enums.Role;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.UUID;

/** Une ligne du tableau des membres. */
@Schema(description = "Ligne du tableau des membres")
public record AdminUserSummary(
        UUID id,
        String fullName,
        String email,
        String avatarUrl,
        Role role,

        @Schema(description = "Faux = compte suspendu ou email jamais verifie")
        boolean enabled,
        boolean emailVerified,

        @Schema(description = "Etat de la candidature, uniquement pour les coachs")
        CoachStatus coachStatus,

        Instant createdAt,
        Instant lastLoginAt
) {}
