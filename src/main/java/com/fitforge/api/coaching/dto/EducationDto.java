package com.fitforge.api.coaching.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

import java.util.UUID;

/** Formation / etude suivie par le coach. */
@Schema(description = "Formation d'un coach")
public record EducationDto(
        UUID id,
        @NotBlank String degree,
        String institution,
        String fieldOfStudy,
        Integer year
) {}
