package com.fitforge.api.training.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Une seance effectuee renvoyee a Flutter (avec ses series).
 */
@Schema(description = "Seance effectuee")
public record WorkoutLogResponse(
        UUID id,
        UUID sessionId,
        LocalDate performedOn,
        Integer durationMinutes,
        Integer rpe,
        List<SetLogResponse> sets
) {}
