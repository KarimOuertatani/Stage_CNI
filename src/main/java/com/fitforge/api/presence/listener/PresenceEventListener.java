package com.fitforge.api.presence.listener;

import com.fitforge.api.presence.service.PresenceService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.security.Principal;
import java.util.UUID;

/**
 * Traduit les evenements de session STOMP en changements de presence.
 *
 * <p>Spring publie {@link SessionConnectedEvent} une fois le CONNECT accepte
 * (donc <b>apres</b> la validation JWT faite par
 * {@code StompAuthChannelInterceptor}) et {@link SessionDisconnectEvent} a la
 * fermeture, <b>quelle qu'en soit la cause</b> : deconnexion propre, app tuee,
 * perte de reseau, heartbeat expire. C'est ce qui rend le statut « en ligne »
 * fiable sans aucun code de nettoyage cote client.
 *
 * <p>Une session non authentifiee (CONNECT sans token valide) n'a pas de
 * principal : elle est ignoree ici, et le registre de presence ne la connait
 * donc jamais.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class PresenceEventListener {

    private final PresenceService presence;

    @EventListener
    public void onSessionConnected(SessionConnectedEvent event) {
        StompHeaderAccessor accessor = StompHeaderAccessor.wrap(event.getMessage());
        UUID userId = userIdOf(accessor.getUser());
        String sessionId = accessor.getSessionId();

        if (userId != null && sessionId != null) {
            presence.userConnected(sessionId, userId);
        }
    }

    @EventListener
    public void onSessionDisconnected(SessionDisconnectEvent event) {
        // On n'a pas besoin du principal ici : le registre retrouve le
        // proprietaire a partir du sessionId, ce qui fonctionne meme quand la
        // deconnexion est brutale et que les en-tetes sont incomplets.
        String sessionId = event.getSessionId();
        if (sessionId != null) {
            presence.userDisconnected(sessionId);
        }
    }

    /** Le principal STOMP porte l'id du compte sous forme de chaine. */
    private UUID userIdOf(Principal principal) {
        if (principal == null) {
            return null;
        }
        try {
            return UUID.fromString(principal.getName());
        } catch (IllegalArgumentException e) {
            log.warn("Presence : principal STOMP inattendu (« {} »), session ignoree",
                    principal.getName());
            return null;
        }
    }
}
