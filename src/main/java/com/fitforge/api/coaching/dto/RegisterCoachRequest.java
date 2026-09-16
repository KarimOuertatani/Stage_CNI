package com.fitforge.api.coaching.dto;

import com.fitforge.api.common.enums.CoachSpecialty;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.util.Set;

/**
 * Inscription d'un COACH : compte + informations professionnelles de base.
 * Le profil complet (certifications, formations, experiences) est ensuite
 * enrichi via PUT /coach/me.
 */
@Schema(description = "Requete d'inscription d'un coach")
public record RegisterCoachRequest(

        @NotBlank @Email String email,

        @NotBlank @Size(min = 8, message = "le mot de passe doit faire au moins 8 caracteres")
        String password,

        @NotBlank String fullName,

        String phoneNumber,

        @Schema(example = "Coach force & prise de masse")
        String headline,

        @Schema(example = "8") @PositiveOrZero Integer yearsExperience,

        Set<CoachSpecialty> specialties
) {}
