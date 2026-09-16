package com.fitforge.api.common.enums;

/**
 * Provenance d'un aliment <b>stocke dans le catalogue local</b>.
 *
 * <ul>
 *   <li>{@code USDA}            : importe depuis USDA FoodData Central
 *       (porte un {@code usdaFdcId}). Aliments generiques de reference.</li>
 *   <li>{@code OPEN_FOOD_FACTS} : importe depuis Open Food Facts
 *       (porte un {@code offCode}, le code-barres). Produits emballes et
 *       de marque, que USDA couvre mal.</li>
 *   <li>{@code CUSTOM}          : saisi manuellement par un adherent (aliment
 *       maison, recette perso, produit local absent des deux bases).</li>
 * </ul>
 *
 * <p>A ne pas confondre avec {@link FoodResultSource}, qui decrit d'ou vient
 * un <i>resultat de recherche</i> (et non ou l'aliment a ete cree).
 */
public enum FoodSource {
    USDA,
    OPEN_FOOD_FACTS,
    CUSTOM
}
