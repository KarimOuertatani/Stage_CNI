package com.fitforge.api.admin.dto;

import com.fitforge.api.coaching.dto.CertificationDto;
import com.fitforge.api.coaching.dto.CoachDocumentResponse;
import com.fitforge.api.coaching.dto.EducationDto;
import com.fitforge.api.coaching.dto.ExperienceDto;
import com.fitforge.api.common.enums.CoachSpecialty;
import com.fitforge.api.common.enums.CoachStatus;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Le dossier complet, tel que l'administrateur l'examine.
 *
 * <h2>Ce que cette structure met deliberement en vis-a-vis</h2>
 * D'un cote les <b>titres revendiques</b> ({@code certifications},
 * {@code educations}), qui sont du texte libre saisi par le coach. De l'autre
 * les <b>justificatifs</b> ({@code documents}), qui sont des fichiers.
 *
 * <p>C'est cette confrontation qui constitue l'examen : un intitule sans piece
 * correspondante est une affirmation non verifiee, une piece dont le nom ne
 * correspond a aucun intitule est un document sans objet, et un nom sur un
 * diplome qui differe de {@code fullName} est le signal de fraude le plus
 * courant. Renvoyer les deux ensembles separement, plutot que fusionnes, laisse
 * ces ecarts visibles.
 */
@Schema(description = "Dossier de candidature coach, vue administrateur")
public record AdminCoachApplicationDetail(

        UUID profileId,
        UUID userId,

        // ── Identite du compte ───────────────────────────────────
        @Schema(description = "Nom du compte. A comparer au nom porte par les justificatifs.")
        String fullName,
        String email,
        String phoneNumber,
        String avatarUrl,
        Instant registeredAt,
        boolean emailVerified,

        // ── Profil professionnel declare ─────────────────────────
        String headline,
        String bio,
        Integer yearsExperience,
        Double hourlyRate,
        String city,
        Set<CoachSpecialty> specialties,

        // ── Titres revendiques (texte) ───────────────────────────
        List<CertificationDto> certifications,
        List<EducationDto> educations,
        List<ExperienceDto> experiences,

        // ── Pieces deposees (fichiers) ───────────────────────────
        List<CoachDocumentResponse> documents,

        // ── Etat et historique de la decision ────────────────────
        CoachStatus status,
        Instant submittedAt,
        Instant reviewedAt,

        @Schema(description = "Nom de l'administrateur ayant tranche")
        String reviewedByName,

        @Schema(description = "Motif du dernier refus ou de la suspension")
        String rejectionReason
) {}
