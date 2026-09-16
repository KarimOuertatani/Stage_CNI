package com.fitforge.api.training.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;
import java.util.UUID;

/**
 * Seance-type renvoyee avec ses exercices places.
 */
@Schema(description = "Seance-type d'un programme")
public record SessionResponse(
        UUID id,
        String title,
        Integer dayOfWeek,
        Integer orderIndex,
        List<SessionExerciseResponse> exercises
) {}
