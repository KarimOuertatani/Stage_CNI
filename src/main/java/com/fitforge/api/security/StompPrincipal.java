package com.fitforge.api.security;

import java.security.Principal;

/**
 * Principal minimal porte par une session STOMP : son nom est l'id (UUID) du
 * compte connecte. C'est ce nom qui permet a Spring de router les messages vers
 * {@code /user/{userId}/queue/...} (livraison privee du chat).
 */
public record StompPrincipal(String name) implements Principal {

    @Override
    public String getName() {
        return name;
    }
}
