package com.fitforge.api.coaching.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Size;

/**
 * Demande de suivi envoyee par un adherent a un coach (message d'accompagnement).
 */
@Schema(description = "Demande de suivi coaching")
public record CreateCoachingRequestRequest(
        @Schema(example = "Bonjour, je souhaite progresser en force, pouvez-vous m'accompagner ?")
        @Size(max = 1000) String message
) {}
