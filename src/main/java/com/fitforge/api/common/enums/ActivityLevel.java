package com.fitforge.api.common.enums;

/**
 * Rythme de vie / niveau d'activite quotidienne (hors sport structure).
 * C'est le facteur multiplicateur du BMR pour obtenir le TDEE :
 *   SEDENTAIRE = 1.2, LEGER = 1.375, MODERE = 1.55,
 *   ACTIF = 1.725, TRES_ACTIF = 1.9
 * (voir ProfileService#recomputeDerived).
 */
public enum ActivityLevel {
    SEDENTAIRE,
    LEGER,
    MODERE,
    ACTIF,
    TRES_ACTIF
}
