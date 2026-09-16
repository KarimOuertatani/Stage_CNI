package com.fitforge.api.training.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

/**
 * Donnees pour ajouter une seance-type a un programme.
 */
@Schema(description = "Ajout d'une seance a un programme")
public record CreateSessionRequest(

        @Schema(example = "Push - Jour 1")
        @NotBlank String title,

        @Schema(description = "Jour de la semaine (1=lundi .. 7=dimanche)", example = "1")
        @Min(1) @Max(7) Integer dayOfWeek,

        @Schema(description = "Ordre d'affichage dans le programme", example = "0")
        Integer orderIndex
) {}
