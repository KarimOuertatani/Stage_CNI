package com.fitforge.api.common.enums;

/**
 * Nature d'un fichier joint (message de chat ou avatar).
 * - IMAGE : photo (jpg, png, webp, gif...).
 * - AUDIO : message vocal / audio.
 * - FILE  : tout autre document (pdf, docx, zip...).
 */
public enum MediaKind {
    IMAGE,
    AUDIO,
    FILE
}
