package com.fitforge.api.common.enums;

/**
 * Sujet d'un echange avec le coach IA, tel que le modele l'a classe.
 *
 * <p>Ce n'est pas une donnee decorative : c'est le <b>pivot du perimetre</b>.
 * {@link #HORS_SUJET} declenche un refus, et {@link #BLESSURE} active des
 * garde-fous supplementaires (aucun medicament, orientation vers un
 * professionnel).
 *
 * <p>Le sujet est aussi persiste avec chaque reponse : il rend le comportement
 * du coach <b>auditable</b> apres coup, sans avoir a relire les conversations.
 */
public enum AiCoachTopic {
    /** Entrainement : exercices, programmes, technique, charges, recuperation. */
    ENTRAINEMENT,
    /** Nutrition : macros, repas, hydratation, complements alimentaires. */
    NUTRITION,
    /** Douleur, gene, blessure. <b>Perimetre le plus encadre.</b> */
    BLESSURE,
    /** Motivation, regularite, habitudes — lie a la pratique sportive. */
    MOTIVATION,
    /** En dehors du perimetre sportif : la demande est declinee poliment. */
    HORS_SUJET
}
