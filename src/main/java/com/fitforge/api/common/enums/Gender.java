package com.fitforge.api.common.enums;

/**
 * Sexe biologique de l'adherent.
 * Utilise dans le calcul du metabolisme de base (BMR) : la formule
 * Mifflin-St Jeor ajoute +5 pour un homme et -161 pour une femme.
 */
public enum Gender {
    HOMME,
    FEMME,
    AUTRE
}
