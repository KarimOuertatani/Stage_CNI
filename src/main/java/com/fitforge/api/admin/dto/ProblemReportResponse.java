package com.fitforge.api.admin.dto;

import com.fitforge.api.admin.entity.ProblemReport;
import com.fitforge.api.common.enums.ProblemCategory;
import com.fitforge.api.common.enums.ProblemStatus;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.UUID;

/**
 * Un signalement, vu par <b>son auteur</b> dans l'ecran « Mes signalements ».
 *
 * <p>Il porte deliberement {@code status} et {@code adminResponse}. Sans eux,
 * l'ecran ne serait qu'un historique de ce qu'on a envoye -- et un signalement
 * qui ne revient jamais donne le sentiment que personne ne lit. C'est ce retour
 * qui fait la difference entre un formulaire de contact et un vrai canal.
 *
 * <p>En revanche, ni l'identite de l'administrateur qui a traite ni les
 * metadonnees techniques ne remontent : elles n'aident pas l'auteur et
 * exposeraient l'organisation interne.
 */
@Schema(description = "Signalement, vue de son auteur")
public record ProblemReportResponse(
        UUID id,
        ProblemCategory category,
        String subject,
        String description,
        String attachmentUrl,
        ProblemStatus status,

        @Schema(description = "Reponse de l'equipe FitForge ; null tant qu'il n'y en a pas")
        String adminResponse,

        Instant createdAt,
        Instant handledAt
) {
    public static ProblemReportResponse from(ProblemReport r) {
        return new ProblemReportResponse(
                r.getId(), r.getCategory(), r.getSubject(), r.getDescription(),
                r.getAttachmentUrl(), r.getStatus(), r.getAdminResponse(),
                r.getCreatedAt(), r.getHandledAt());
    }
}
