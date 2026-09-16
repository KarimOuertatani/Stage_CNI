package com.fitforge.api.common.enums;

/**
 * Nature d'un probleme signale par un utilisateur.
 *
 * <p>La categorie sert d'abord a <b>trier la file</b> : un bug bloquant et une
 * suggestion d'amelioration ne se traitent ni dans le meme delai ni par le meme
 * geste. Elle est choisie par l'utilisateur, donc parfois approximative -- c'est
 * accepte : une categorie a peu pres juste vaut mieux qu'un champ libre ou tout
 * arrive en vrac, et l'administrateur peut de toute facon lire le detail.
 *
 * <p>La liste est volontairement <b>courte</b>. Au-dela de six ou sept choix,
 * l'utilisateur ne lit plus et prend le premier : une taxonomie fine produit
 * des donnees moins fiables qu'une taxonomie grossiere.
 */
public enum ProblemCategory {

    /** Quelque chose ne fonctionne pas : plantage, ecran vide, bouton sans effet. */
    BUG,

    /** Connexion, mot de passe, verification d'email, acces au compte. */
    ACCOUNT,

    /** Donnee fausse : macros d'un aliment, video d'exercice, calcul de score. */
    CONTENT,

    /** Comportement inapproprie d'un coach ou d'un adherent. */
    ABUSE,

    /** Proposition d'amelioration. */
    SUGGESTION,

    /** Tout le reste. */
    OTHER
}
