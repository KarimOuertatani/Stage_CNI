package com.fitforge.api.coaching.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.UUID;

/** Reference legere vers une personne (coach ou adherent) pour les listes. */
@Schema(description = "Reference d'une personne")
public record PersonRef(
        UUID userId,
        String fullName,
        String avatarUrl,
        String headline
) {}
