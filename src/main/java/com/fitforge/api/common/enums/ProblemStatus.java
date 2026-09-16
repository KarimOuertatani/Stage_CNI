package com.fitforge.api.common.enums;

/**
 * Avancement du traitement d'un signalement.
 *
 * <p>Ces quatre etats sont <b>visibles par l'utilisateur</b> qui a signale, et
 * c'est leur raison d'etre principale. Un signalement envoye dans le vide donne
 * le sentiment que personne ne lit : la valeur de ce module tient autant au
 * retour rendu qu'au traitement lui-meme.
 *
 * <p>RESOLVED et CLOSED disent deux choses differentes et ne doivent pas etre
 * fusionnes. RESOLVED = « tu avais raison, c'est corrige ». CLOSED = « nous
 * avons regarde et il n'y a rien a faire » (doublon, comportement normal,
 * demande hors perimetre). Les confondre reviendrait a annoncer une correction
 * qui n'a pas eu lieu.
 */
public enum ProblemStatus {

    /** Recu, pas encore ouvert par l'administration. */
    NEW,

    /** Pris en charge : quelqu'un s'en occupe. */
    IN_PROGRESS,

    /** Traite : le probleme a ete corrige ou la demande satisfaite. */
    RESOLVED,

    /** Clos sans correction : doublon, hors perimetre, ou comportement normal. */
    CLOSED
}
