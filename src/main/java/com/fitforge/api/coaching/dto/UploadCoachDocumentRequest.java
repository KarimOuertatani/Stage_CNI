package com.fitforge.api.coaching.dto;

import com.fitforge.api.common.enums.CoachDocumentType;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Metadonnees accompagnant l'envoi d'un justificatif. Le fichier lui-meme
 * voyage a part, en multipart.
 */
@Schema(description = "Metadonnees d'un justificatif a deposer")
public record UploadCoachDocumentRequest(

        @NotNull(message = "Le type de justificatif est obligatoire")
        CoachDocumentType type,

        @Size(max = 255, message = "L'intitule ne peut pas depasser 255 caracteres")
        @Schema(description = "Ce que le document est cense montrer", example = "Master STAPS 2021")
        String label
) {}
