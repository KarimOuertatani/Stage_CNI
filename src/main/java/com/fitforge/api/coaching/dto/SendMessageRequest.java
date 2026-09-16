package com.fitforge.api.coaching.dto;

import com.fitforge.api.common.enums.MediaKind;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Size;

/**
 * Envoi d'un message dans un fil de coaching.
 *
 * Le message porte du texte, une piece jointe, ou les deux. La piece jointe est
 * d'abord uploadee via {@code POST /media} ; on ne transmet ici que son URL et
 * ses metadonnees.
 */
@Schema(description = "Message de chat a envoyer (texte et/ou piece jointe)")
public record SendMessageRequest(
        @Size(max = 2000) String content,
        @Size(max = 512) String attachmentUrl,
        MediaKind attachmentKind,
        @Size(max = 255) String attachmentName,
        Long attachmentSize,
        Integer attachmentDurationSec
) {
    /** Un message doit avoir au moins du texte OU une piece jointe. */
    @AssertTrue(message = "Le message doit contenir du texte ou une piece jointe")
    @Schema(hidden = true)
    public boolean isNotEmpty() {
        boolean hasText = content != null && !content.isBlank();
        boolean hasAttachment = attachmentUrl != null && !attachmentUrl.isBlank();
        return hasText || hasAttachment;
    }
}
