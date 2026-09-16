package com.fitforge.api.training.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.UUID;

/**
 * Une serie realisee renvoyee a Flutter (avec le detail de l'exercice).
 */
@Schema(description = "Serie realisee")
public record SetLogResponse(
        UUID id,
        ExerciseResponse exercise,
        Integer setNumber,
        Integer reps,
        Double weightKg,
        boolean completed
) {}
