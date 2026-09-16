package com.fitforge.api.common.enums;

/**
 * Les fonctions de l'application qui appellent un modele de langage.
 *
 * <h2>Pourquoi les distinguer alors qu'elles partagent la meme cle</h2>
 * Justement <b>parce qu'</b>elles la partagent. Quand le quota est atteint ou
 * que le service repond 503, tout tombe en meme temps -- et un compteur global
 * dirait seulement « l'IA est en panne », sans permettre de savoir laquelle des
 * cinq fonctions a consomme le quota des autres.
 *
 * <p>Elles n'ont d'ailleurs ni le meme modele, ni le meme delai d'attente, ni le
 * meme cout : la generation de programme est l'appel le plus lourd de
 * l'application (catalogue d'exercices en entree, plusieurs seances en sortie),
 * le coach IA le plus frequent. Melanger leurs latences dans une moyenne unique
 * produirait un nombre qui ne decrit aucune des deux.
 */
public enum AiFeature {

    /** Coach IA : conversation textuelle bornee au sport. */
    COACH_CHAT,

    /** Analyse d'une photo de repas. */
    MEAL_PHOTO,

    /** Ajout d'un repas dicte a la voix (transcription + extraction). */
    MEAL_VOICE,

    /** Meme analyse a partir d'une phrase ecrite (repli du vocal). */
    MEAL_TEXT,

    /** Generation d'un programme d'entrainement complet. */
    PROGRAM_GENERATION,

    /**
     * Appel de controle declenche depuis la console d'administration.
     *
     * <p>Journalise comme les autres, et c'est voulu : une sonde qui ne
     * laisserait pas de trace ne permettrait pas de reconstituer, apres coup,
     * ce que l'on savait de l'etat du service a un moment donne.
     */
    HEALTH_PROBE
}
