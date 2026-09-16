package com.fitforge.api.common.enums;

/**
 * Nature d'une notification destinee a l'administration.
 *
 * <p>Le type porte deux informations que le texte ne porte pas : <b>vers quel
 * ecran</b> la console doit envoyer au clic, et <b>quelle icone et quelle
 * couleur</b> afficher. Se reposer sur le libelle pour cela obligerait a
 * analyser une chaine de caracteres pour decider d'une navigation -- et une
 * simple reformulation casserait les liens.
 */
public enum AdminNotificationType {

    /** Un coach a soumis son dossier : il attend une decision. */
    COACH_APPLICATION_SUBMITTED,

    /** Un nouvel adherent a cree son compte. */
    MEMBER_REGISTERED,

    /** Un utilisateur a signale un probleme. */
    PROBLEM_REPORTED
}
