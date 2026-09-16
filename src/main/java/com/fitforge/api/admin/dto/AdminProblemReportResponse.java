package com.fitforge.api.admin.dto;

import com.fitforge.api.admin.entity.ProblemReport;
import com.fitforge.api.common.enums.ProblemCategory;
import com.fitforge.api.common.enums.ProblemStatus;
import com.fitforge.api.common.enums.Role;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.UUID;

/**
 * Un signalement, vu par l'administration.
 *
 * <p>Superset de {@link ProblemReportResponse} : s'y ajoutent l'auteur (pour
 * pouvoir le recontacter ou consulter sa fiche) et le contexte technique, qui
 * est souvent ce qui permet de reproduire le probleme.
 *
 * <p>Un seul DTO sert la liste et le detail, contrairement aux candidatures
 * coach qui en ont deux. La raison est concrete : un signalement tient en
 * quelques champs deja tous charges, alors qu'un dossier de coach traine
 * derriere lui trois listes et des fichiers -- la ou economiser le chargement
 * a un sens.
 */
@Schema(description = "Signalement, vue administrateur")
public record AdminProblemReportResponse(
        UUID id,

        // ── Auteur ───────────────────────────────────────────────
        UUID reporterId,
        String reporterName,
        String reporterEmail,
        String reporterAvatarUrl,

        @Schema(description = "Role de l'auteur au moment du signalement")
        Role reporterRole,

        // ── Contenu ──────────────────────────────────────────────
        ProblemCategory category,
        String subject,
        String description,
        String attachmentUrl,

        // ── Contexte technique ───────────────────────────────────
        String platform,
        String appVersion,

        // ── Traitement ───────────────────────────────────────────
        ProblemStatus status,
        String adminResponse,
        String handledByName,
        Instant handledAt,
        Instant createdAt,
        Instant updatedAt
) {
    public static AdminProblemReportResponse from(ProblemReport r) {
        return new AdminProblemReportResponse(
                r.getId(),
                r.getReporter().getId(),
                r.getReporter().getFullName(),
                r.getReporter().getEmail(),
                r.getReporter().getAvatarUrl(),
                r.getReporterRole(),
                r.getCategory(), r.getSubject(), r.getDescription(), r.getAttachmentUrl(),
                r.getPlatform(), r.getAppVersion(),
                r.getStatus(), r.getAdminResponse(),
                r.getHandledBy() == null ? null : r.getHandledBy().getFullName(),
                r.getHandledAt(), r.getCreatedAt(), r.getUpdatedAt());
    }
}
