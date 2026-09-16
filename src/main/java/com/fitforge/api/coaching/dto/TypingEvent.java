package com.fitforge.api.coaching.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.UUID;

/**
 * Signal « en train d'ecrire », echange <b>uniquement</b> par WebSocket.
 *
 * <p>Le meme record sert dans les deux sens :
 * <ul>
 *   <li><b>client -&gt; serveur</b> sur {@code /app/typing} : seuls
 *       {@code relationshipId} et {@code typing} sont lus, {@code userId} est
 *       ignore (il est deduit du principal STOMP, jamais du message — sinon
 *       n'importe qui pourrait se faire passer pour un autre) ;</li>
 *   <li><b>serveur -&gt; client</b> sur {@code /user/queue/typing} : les trois
 *       champs sont renseignes.</li>
 * </ul>
 *
 * <p>Volontairement <b>non persiste</b> : une frappe n'a de valeur que dans la
 * seconde qui suit. Si le destinataire est absent, le signal est simplement
 * perdu, ce qui est le comportement attendu.
 */
@Schema(description = "Signal de frappe en cours dans une conversation")
public record TypingEvent(

        @Schema(description = "Conversation concernee")
        UUID relationshipId,

        @Schema(description = "Auteur de la frappe (renseigne par le serveur)")
        UUID userId,

        @Schema(description = "Vrai s'il est en train d'ecrire, faux s'il s'est arrete")
        boolean typing
) {
}
