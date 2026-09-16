package com.fitforge.api.nutrition.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import java.util.List;

/**
 * Mapping brut des reponses de l'API USDA FoodData Central.
 *
 * <p>Tous les records ignorent les champs inconnus : USDA renvoie des dizaines
 * de proprietes dont on n'a pas besoin, et le schema evolue sans preavis.
 *
 * <p><b>Piege majeur — deux formats de nutriments.</b> L'API n'utilise pas la
 * meme forme selon l'endpoint :
 * <pre>
 *   GET /foods/search   ->  { "nutrientId": 1003, "value": 31.0 }
 *   GET /food/{fdcId}   ->  { "nutrient": { "id": 1003 }, "amount": 31.0 }
 * </pre>
 * {@link Nutrient} accepte les deux et expose {@code resolvedId()} /
 * {@code resolvedValue()} pour lire indifferemment l'un ou l'autre.
 */
public final class UsdaDtos {

    private UsdaDtos() {
    }

    // ── Identifiants des nutriments USDA ──────────────────────────────

    /** Energie en kilocalories. */
    public static final int NUTRIENT_ENERGY_KCAL = 1008;
    /** Energie (facteurs Atwater generaux) — repli quand 1008 est absent. */
    public static final int NUTRIENT_ENERGY_ATWATER_GENERAL = 2047;
    /** Energie (facteurs Atwater specifiques) — second repli. */
    public static final int NUTRIENT_ENERGY_ATWATER_SPECIFIC = 2048;
    /** Proteines (g). */
    public static final int NUTRIENT_PROTEIN = 1003;
    /** Lipides totaux (g). */
    public static final int NUTRIENT_FAT = 1004;
    /** Glucides par difference (g). */
    public static final int NUTRIENT_CARBS = 1005;
    /** Fibres alimentaires totales (g). */
    public static final int NUTRIENT_FIBER = 1079;

    // ── Reponse de GET /foods/search ──────────────────────────────────

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record SearchResponse(
            Integer totalHits,
            List<Food> foods
    ) {
    }

    // ── Aliment (commun aux deux endpoints) ───────────────────────────

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Food(
            Long fdcId,
            String description,
            String dataType,
            /** Marque : renseignee pour les aliments "Branded". */
            String brandOwner,
            String brandName,
            List<Nutrient> foodNutrients
    ) {
        /** Marque affichable, ou {@code null} si l'aliment n'en a pas. */
        public String resolvedBrand() {
            if (brandName != null && !brandName.isBlank()) return brandName.trim();
            if (brandOwner != null && !brandOwner.isBlank()) return brandOwner.trim();
            return null;
        }

        /**
         * Valeur d'un nutriment par son id USDA, ou {@code null} si absent.
         * Toutes les valeurs USDA sont normalisees POUR 100 g.
         */
        public Double nutrient(int nutrientId) {
            if (foodNutrients == null) return null;
            for (Nutrient n : foodNutrients) {
                Integer id = n.resolvedId();
                if (id != null && id == nutrientId) {
                    return n.resolvedValue();
                }
            }
            return null;
        }

        /**
         * Energie en kcal, avec repli sur les variantes Atwater : certains
         * aliments Foundation ne portent pas le nutriment 1008.
         */
        public Double energyKcal() {
            Double kcal = nutrient(NUTRIENT_ENERGY_KCAL);
            if (kcal != null) return kcal;
            kcal = nutrient(NUTRIENT_ENERGY_ATWATER_GENERAL);
            if (kcal != null) return kcal;
            return nutrient(NUTRIENT_ENERGY_ATWATER_SPECIFIC);
        }

        /** Vrai si l'aliment porte au moins l'energie et une macro exploitable. */
        public boolean hasUsableMacros() {
            return energyKcal() != null
                    || nutrient(NUTRIENT_PROTEIN) != null
                    || nutrient(NUTRIENT_CARBS) != null
                    || nutrient(NUTRIENT_FAT) != null;
        }
    }

    // ── Nutriment : accepte les DEUX formats de l'API ─────────────────

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Nutrient(
            /** Format /foods/search. */
            Integer nutrientId,
            Double value,
            /** Format /food/{fdcId}. */
            NutrientRef nutrient,
            Double amount
    ) {
        public Integer resolvedId() {
            if (nutrientId != null) return nutrientId;
            return nutrient != null ? nutrient.id() : null;
        }

        public Double resolvedValue() {
            return value != null ? value : amount;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record NutrientRef(
            Integer id,
            String name,
            String unitName
    ) {
    }
}
