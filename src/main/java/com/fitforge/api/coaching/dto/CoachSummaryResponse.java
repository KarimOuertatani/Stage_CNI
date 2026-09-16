package com.fitforge.api.coaching.dto;

import com.fitforge.api.common.enums.CoachSpecialty;
import io.swagger.v3.oas.annotations.media.Schema;

import java.util.Set;
import java.util.UUID;

/** Coach resume pour l'annuaire (carte). */
@Schema(description = "Coach (resume annuaire)")
public record CoachSummaryResponse(
        UUID userId,
        UUID profileId,
        String fullName,
        String avatarUrl,
        String headline,
        String city,
        Integer yearsExperience,
        Set<CoachSpecialty> specialties,
        double ratingAverage,
        int ratingCount,
        boolean acceptingClients
) {}
