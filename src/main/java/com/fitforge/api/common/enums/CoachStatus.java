package com.fitforge.api.common.enums;

/**
 * Etat de la candidature d'un coach.
 *
 * <pre>
 *  inscription ──▶ DRAFT ──soumission──▶ PENDING ──▶ APPROVED ──▶ (SUSPENDED)
 *                    ▲                      │
 *                    └─────── REJECTED ◀────┘
 *                          (motif affiche, correction possible)
 * </pre>
 *
 * <p><b>Pourquoi DRAFT existe.</b> Sans lui, un coach qui vient de creer son
 * compte serait deja « en attente de validation » alors qu'il n'a rien depose :
 * la file de l'administrateur se remplirait de dossiers vides, impossibles a
 * examiner et impossibles a distinguer des vraies candidatures. La soumission
 * doit etre un geste explicite du coach, et c'est cette frontiere que DRAFT
 * materialise.
 *
 * <p><b>Pourquoi REJECTED n'est pas terminal.</b> La grande majorite des refus
 * ne sont pas des fraudes mais des dossiers mal remplis -- une photo floue, un
 * diplome hors cadre, un nom qui ne correspond pas parce que le coach a envoye
 * la piece d'identite de quelqu'un d'autre par erreur. Fermer definitivement le
 * compte ferait perdre des coachs legitimes pour un probleme de cadrage. Le
 * refus porte donc un motif, et le coach peut corriger puis resoumettre.
 *
 * <p><b>SUSPENDED est different de REJECTED :</b> il s'applique a un coach
 * <i>deja approuve</i>, retire de l'annuaire apres coup (signalement, litige).
 * Les deux sortent le coach de l'annuaire, mais ils ne racontent pas la meme
 * histoire et ne s'affichent pas pareil.
 */
public enum CoachStatus {

    /** Compte cree, dossier en cours de constitution. Invisible pour tous. */
    DRAFT,

    /** Dossier soumis, en attente d'examen par l'administrateur. */
    PENDING,

    /** Dossier valide : le coach apparait dans l'annuaire et peut exercer. */
    APPROVED,

    /** Dossier refuse avec un motif. Le coach peut corriger et resoumettre. */
    REJECTED,

    /** Coach precedemment approuve, suspendu par l'administration. */
    SUSPENDED
}
