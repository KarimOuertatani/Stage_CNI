package com.fitforge.api.coaching.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

import java.util.UUID;

/** Experience professionnelle du coach. endYear null = en cours. */
@Schema(description = "Experience professionnelle d'un coach")
public record ExperienceDto(
        UUID id,
        @NotBlank String title,
        String organization,
        Integer startYear,
        Integer endYear,
        String description
) {}
