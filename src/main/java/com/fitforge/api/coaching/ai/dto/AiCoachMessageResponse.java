package com.fitforge.api.coaching.ai.dto;

import com.fitforge.api.common.enums.AiCoachRole;
import com.fitforge.api.common.enums.AiCoachTopic;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.util.UUID;

/**
 * Un message du fil avec le coach IA.
 *
 * <p>{@code topic} et {@code refused} sont exposes volontairement : l'app s'en
 * sert pour <b>signaler visuellement</b> une reponse declinee ou un conseil
 * portant sur une blessure. L'adherent voit ainsi pourquoi il a recu ce
 * message-la, au lieu de subir un refus sans explication.
 */
@Schema(description = "Message du fil avec le coach IA")
public record AiCoachMessageResponse(

        @Schema(description = "Identifiant du message")
        UUID id,

        @Schema(description = "Auteur : USER (l'adherent) ou ASSISTANT (le coach IA)",
                example = "ASSISTANT")
        AiCoachRole role,

        @Schema(description = "Contenu du message")
        String content,

        @Schema(description = "Sujet classe par le coach. Null sur les messages de "
                + "l'adherent.", example = "ENTRAINEMENT")
        AiCoachTopic topic,

        @Schema(description = "Vrai si la demande sortait du perimetre sportif et a "
                + "ete declinee")
        boolean refused,

        @Schema(description = "Horodatage")
        Instant createdAt
) {
}
