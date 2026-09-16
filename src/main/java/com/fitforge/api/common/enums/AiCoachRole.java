package com.fitforge.api.common.enums;

/**
 * Auteur d'un message du fil avec le coach IA.
 *
 * <p>Deux valeurs seulement, et volontairement : la consigne systeme n'est
 * <b>jamais</b> stockee comme un message. Elle appartient au code, pas a
 * l'historique — sinon elle serait modifiable par le contenu de la
 * conversation, ce qui est precisement la faille qu'on veut eviter.
 */
public enum AiCoachRole {
    /** Message ecrit par l'adherent. */
    USER,
    /** Reponse du coach IA. */
    ASSISTANT
}
