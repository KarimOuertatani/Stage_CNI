package com.fitforge.api.coaching.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

import java.util.UUID;

/** Certification / diplome professionnel du coach. */
@Schema(description = "Certification d'un coach")
public record CertificationDto(
        UUID id,
        @NotBlank String title,
        String organization,
        Integer year,
        String credentialUrl
) {}
