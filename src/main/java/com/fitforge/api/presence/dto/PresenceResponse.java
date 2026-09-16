package com.fitforge.api.presence.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.UUID;

/**
 * Etat de presence d'un utilisateur.
 *
 * <p>Sert a la fois de reponse REST (a l'ouverture d'une conversation) et de
 * charge utile des evenements STOMP pousses sur {@code /user/queue/presence}
 * quand un interlocuteur se connecte ou se deconnecte.
 */
@Schema(description = "Presence d'un utilisateur (en ligne / derniere activite)")
public record PresenceResponse(

        @Schema(description = "Compte concerne")
        UUID userId,

        @Schema(description = "Vrai si une session temps reel est ouverte", example = "true")
        boolean online,

        @Schema(description = "Derniere activite connue. Null quand l'utilisateur est en ligne "
                + "(l'information n'aurait pas de sens) ou s'il ne s'est jamais connecte.")
        Instant lastSeenAt
) {
}
