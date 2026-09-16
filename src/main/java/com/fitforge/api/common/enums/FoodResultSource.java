package com.fitforge.api.common.enums;

/**
 * D'ou vient un <b>resultat de recherche</b> d'aliment.
 *
 * <p>Repond a la question « qui a fourni cette ligne ? », alors que
 * {@link FoodSource} repond a « d'ou cet aliment a-t-il ete importe ? ». Un
 * yaourt importe d'Open Food Facts la semaine derniere est stocke avec
 * {@code FoodSource.OPEN_FOOD_FACTS}, mais ressort aujourd'hui de la recherche
 * en {@code LOCAL} : il est desormais en cache, son ajout ne declenchera aucun
 * appel externe.
 *
 * <p>L'ordre de declaration est celui d'interrogation des sources.
 *
 * <ul>
 *   <li>{@code LOCAL}           : deja dans notre catalogue — ajout instantane,
 *       zero appel reseau ;</li>
 *   <li>{@code USDA}            : USDA FoodData Central, source de reference
 *       pour les aliments generiques ;</li>
 *   <li>{@code OPEN_FOOD_FACTS} : source d'appoint, interrogee seulement quand
 *       les deux precedentes n'ont rien donne. Couvre les produits emballes
 *       et de marque. Donnees sous licence ODbL.</li>
 * </ul>
 */
public enum FoodResultSource {
    LOCAL,
    USDA,
    OPEN_FOOD_FACTS
}
