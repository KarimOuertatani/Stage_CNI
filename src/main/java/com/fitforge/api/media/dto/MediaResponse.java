package com.fitforge.api.media.dto;

import com.fitforge.api.common.enums.MediaKind;
import io.swagger.v3.oas.annotations.media.Schema;

/**
 * Resultat d'un upload : l'URL publique (relative) du fichier + metadonnees
 * utiles au front pour l'afficher (nom d'origine, type MIME, taille, nature).
 */
@Schema(description = "Fichier uploade")
public record MediaResponse(
        String url,
        String fileName,
        String contentType,
        long size,
        MediaKind kind
) {}
