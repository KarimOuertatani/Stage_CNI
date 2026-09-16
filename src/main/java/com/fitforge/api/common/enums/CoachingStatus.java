package com.fitforge.api.common.enums;

/**
 * Statut de la relation de suivi entre un adherent et un coach.
 * - PENDING  : l'adherent a envoye une demande, le coach n'a pas encore repondu.
 * - ACCEPTED : le coach a accepte -> le suivi (et le chat) sont actifs.
 * - DECLINED : le coach a refuse la demande.
 * - ENDED    : le suivi a ete termine (par l'un ou l'autre).
 */
public enum CoachingStatus {
    PENDING,
    ACCEPTED,
    DECLINED,
    ENDED
}
