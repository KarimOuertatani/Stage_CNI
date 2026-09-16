package com.fitforge.api.training.dto;

import com.fitforge.api.common.enums.ExperienceLevel;
import com.fitforge.api.common.enums.FitnessGoal;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/**
 * Donnees pour creer ou mettre a jour un programme.
 */
@Schema(description = "Creation/mise a jour d'un programme d'entrainement")
public record CreateProgramRequest(

        @Schema(example = "Prise de masse 4 semaines")
        @NotBlank String title,

        @Schema(example = "Mon programme perso de prise de masse")
        @Size(max = 500) String description,

        FitnessGoal goal,

        @Schema(description = "Niveau conseille", example = "INTERMEDIAIRE")
        ExperienceLevel experienceLevel,

        @Schema(example = "4") @Positive Integer durationWeeks,

        @Schema(description = "Programme modele reutilisable ?", example = "false")
        boolean isTemplate
) {}
