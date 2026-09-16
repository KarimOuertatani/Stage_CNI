package com.fitforge.api.coaching.dto;

import com.fitforge.api.common.enums.CoachSpecialty;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.Set;

/**
 * Donnees pour creer / mettre a jour le profil professionnel du coach connecte.
 * Les listes remplacent integralement les listes existantes (edition complete).
 */
@Schema(description = "Creation/mise a jour du profil coach")
public record UpsertCoachProfileRequest(

        @Schema(example = "Coach force & prise de masse")
        @Size(max = 255) String headline,

        @Schema(example = "10 ans d'accompagnement, specialiste des debutants...")
        @Size(max = 2000) String bio,

        @Schema(example = "8") @PositiveOrZero Integer yearsExperience,

        @Schema(example = "40.0") @PositiveOrZero Double hourlyRate,

        @Schema(example = "Tunis") String city,

        @Schema(description = "Accepte de nouveaux adherents ?", example = "true")
        Boolean acceptingClients,

        Set<CoachSpecialty> specialties,

        @Valid List<CertificationDto> certifications,
        @Valid List<EducationDto> educations,
        @Valid List<ExperienceDto> experiences
) {}
