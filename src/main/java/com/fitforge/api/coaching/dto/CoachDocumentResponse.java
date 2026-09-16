package com.fitforge.api.coaching.dto;

import com.fitforge.api.coaching.entity.CoachDocument;
import com.fitforge.api.common.enums.CoachDocumentType;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.UUID;

/**
 * Un justificatif, tel qu'il est decrit dans les reponses de l'API.
 *
 * <p><b>La cle de stockage n'y figure pas</b>, et c'est deliberé : elle n'a
 * aucun usage pour un client, et l'exposer inviterait a construire des URLs
 * a la main. Le fichier se recupere par l'identifiant, via une route qui
 * verifie les droits.
 */
@Schema(description = "Justificatif depose par un coach")
public record CoachDocumentResponse(
        UUID id,
        CoachDocumentType type,
        @Schema(description = "Intitule saisi par le coach", example = "BPJEPS AGFF 2019")
        String label,
        String originalName,
        String contentType,
        Long sizeBytes,
        Instant uploadedAt
) {
    public static CoachDocumentResponse from(CoachDocument d) {
        return new CoachDocumentResponse(
                d.getId(), d.getType(), d.getLabel(), d.getOriginalName(),
                d.getContentType(), d.getSizeBytes(), d.getUploadedAt());
    }
}
