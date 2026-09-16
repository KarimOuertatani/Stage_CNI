package com.fitforge.api.coaching.controller;

import com.fitforge.api.coaching.dto.TypingEvent;
import com.fitforge.api.coaching.service.ChatService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.stereotype.Controller;

import java.security.Principal;
import java.util.UUID;

/**
 * Point d'entree WebSocket du signal « en train d'ecrire ».
 *
 * <p>Seul endroit du projet ou le client <b>envoie</b> par STOMP : l'envoi des
 * messages reste en REST (source de verite, persistee). Ici il n'y a rien a
 * persister ni a garantir — c'est un signal ephemere, et le passer par HTTP
 * serait un aller-retour inutile toutes les quelques secondes.
 *
 * <p>Destination cliente : {@code /app/typing}.
 */
@Controller
@RequiredArgsConstructor
@Slf4j
public class ChatTypingController {

    private final ChatService chatService;

    @MessageMapping("/typing")
    public void onTyping(TypingEvent event, Principal principal) {
        if (principal == null || event == null || event.relationshipId() == null) {
            return;   // session non authentifiee ou message incomplet
        }

        try {
            UUID senderId = UUID.fromString(principal.getName());
            chatService.relayTyping(senderId, event.relationshipId(), event.typing());

        } catch (IllegalArgumentException e) {
            log.warn("Frappe : principal STOMP inattendu, signal ignore");

        } catch (RuntimeException e) {
            // Fil inexistant, acces refuse, destinataire absent : un signal de
            // frappe ne doit JAMAIS remonter d'erreur au client ni polluer les
            // logs en erreur. On l'abandonne silencieusement.
            log.debug("Frappe : signal abandonne ({})", e.getMessage());
        }
    }
}
