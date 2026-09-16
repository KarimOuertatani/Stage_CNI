package com.fitforge.api.coaching.dto;

import com.fitforge.api.common.enums.CoachSpecialty;
import com.fitforge.api.common.enums.CoachStatus;
import com.fitforge.api.common.enums.CoachingStatus;
import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Profil coach complet consultable par un adherent (ou par le coach lui-meme).
 * [viewerRelationStatus] = statut de la relation entre le demandeur et ce coach
 * (null si aucune relation), pour piloter le bouton "Demander un suivi".
 */
@Schema(description = "Profil coach complet")
public record CoachProfileResponse(
        UUID userId,
        UUID profileId,
        String fullName,
        String avatarUrl,
        String headline,
        String bio,
        Integer yearsExperience,
        Double hourlyRate,
        String city,
        CoachStatus status,
        boolean acceptingClients,
        double ratingAverage,
        int ratingCount,
        Set<CoachSpecialty> specialties,
        List<CertificationDto> certifications,
        List<EducationDto> educations,
        List<ExperienceDto> experiences,
        CoachingStatus viewerRelationStatus,
        UUID viewerRelationshipId
) {}
