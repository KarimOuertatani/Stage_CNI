package com.fitforge.api.coaching.dto;

import com.fitforge.api.common.enums.CoachingStatus;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.UUID;

/**
 * Relation de suivi renvoyee au front (vue coach OU vue adherent). Inclut un
 * apercu du dernier message et le nombre de non-lus pour la liste des messages.
 */
@Schema(description = "Relation de suivi coaching")
public record CoachingRelationshipResponse(
        UUID id,
        CoachingStatus status,
        String requestMessage,
        Instant createdAt,
        Instant respondedAt,
        PersonRef coach,
        PersonRef member,
        String lastMessage,
        Instant lastMessageAt,
        long unreadCount
) {}
