package com.fitforge.api.user.dto;

import com.fitforge.api.common.enums.Role;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.UUID;

/**
 * Infos du compte connecte renvoyees par GET /auth/me.
 * On n'expose jamais le mot de passe hashe.
 */
@Schema(description = "Informations du compte connecte")
public record AccountResponse(
        UUID id,
        String email,
        String fullName,
        String phoneNumber,
        String avatarUrl,
        Role role,
        boolean emailVerified,
        Instant createdAt,
        Instant lastLoginAt
) {}
