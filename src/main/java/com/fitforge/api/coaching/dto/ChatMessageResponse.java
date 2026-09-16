package com.fitforge.api.coaching.dto;

import com.fitforge.api.common.enums.MediaKind;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.UUID;

/** Message de chat renvoye au front (texte et/ou piece jointe). */
@Schema(description = "Message de chat")
public record ChatMessageResponse(
        UUID id,
        UUID relationshipId,
        UUID senderId,
        String senderName,
        String content,
        String attachmentUrl,
        MediaKind attachmentKind,
        String attachmentName,
        Long attachmentSize,
        Integer attachmentDurationSec,
        Instant sentAt,
        Instant readAt
) {}
