package com.fitforge.api.training.dto;

import com.fitforge.api.common.enums.ExperienceLevel;
import com.fitforge.api.common.enums.FitnessGoal;
import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;
import java.util.UUID;

/**
 * Programme complet renvoye a Flutter (avec ses seances et leurs exercices).
 */
@Schema(description = "Programme d'entrainement complet")
public record ProgramResponse(
        UUID id,
        String title,
        String description,
        FitnessGoal goal,
        ExperienceLevel experienceLevel,
        Integer durationWeeks,
        boolean isTemplate,
        UUID createdById,
        String createdByName,

        @Schema(description = "Programme compose par l'IA FitForge", example = "false")
        boolean generatedByAi,

        @Schema(description = "Le mot de l'IA : pourquoi ce decoupage, ce volume, ces exercices. "
                + "Null pour un programme non genere.")
        String aiRationale,

        List<SessionResponse> sessions
) {}
