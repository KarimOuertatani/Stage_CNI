package com.fitforge.api.admin.dto;

import com.fitforge.api.common.enums.CoachStatus;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.UUID;

/**
 * Une ligne de la file des candidatures.
 *
 * <p>Contient exactement ce qui permet de <b>trier et prioriser</b> sans ouvrir
 * le dossier : qui, depuis quand, combien de pieces. Charger le profil complet
 * de chaque coach pour afficher une liste de vingt lignes ferait payer a
 * l'ecran d'accueil de la console le cout de vingt fiches detaillees.
 */
@Schema(description = "Ligne de la file des candidatures coach")
public record AdminCoachApplicationSummary(
        UUID profileId,
        UUID userId,
        String fullName,
        String email,
        String avatarUrl,
        CoachStatus status,
        String headline,
        String city,
        Integer yearsExperience,

        @Schema(description = "Nombre de justificatifs deposes")
        int documentCount,

        @Schema(description = "Date de soumission ; null si le dossier est encore en brouillon")
        Instant submittedAt,
        Instant reviewedAt,
        Instant registeredAt
) {}
