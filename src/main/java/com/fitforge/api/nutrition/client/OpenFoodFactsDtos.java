package com.fitforge.api.nutrition.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * Mapping des reponses <b>Open Food Facts</b>.
 *
 * <p>Volontairement minimal : la base OFF expose des centaines de champs par
 * produit, on ne lit que ceux dont le journal alimentaire a besoin. Tous les
 * records ignorent les champs inconnus — le schema evolue au fil des
 * contributions de la communaute.
 *
 * <p><b>Convention.</b> Comme USDA, les nutriments {@code *_100g} sont exprimes
 * <b>pour 100 g</b>, ce qui les rend directement compatibles avec le calcul au
 * prorata du module nutrition.
 */
public final class OpenFoodFactsDtos {

    private OpenFoodFactsDtos() {
    }

    /** Reponse de {@code /cgi/search.pl?json=1}. */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record SearchResponse(List<Product> products) {
    }

    /** Reponse de {@code /api/v2/product/{code}.json}. */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record ProductResponse(
            /* 1 = trouve, 0 = code-barres inconnu */
            Integer status,
            Product product
    ) {
        public boolean found() {
            return status != null && status == 1 && product != null;
        }
    }

    /**
     * Un produit du catalogue Open Food Facts.
     *
     * @param code            code-barres (GTIN/EAN) — <b>cle de deduplication du cache</b>
     * @param productName     libelle brut
     * @param productNameFr   libelle francais quand le contributeur l'a renseigne
     * @param brands          marques, separees par des virgules
     * @param nutriments      valeurs nutritionnelles
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Product(
            String code,
            @JsonProperty("product_name") String productName,
            @JsonProperty("product_name_fr") String productNameFr,
            String brands,
            Nutriments nutriments
    ) {

        /**
         * Libelle a afficher, <b>francais de preference</b>.
         *
         * <p>Contrairement a USDA, OFF est multilingue : quand le champ
         * francais existe il est deja dans la bonne langue et n'a pas besoin
         * de passer par le lexique culinaire.
         */
        public String resolvedName() {
            if (productNameFr != null && !productNameFr.isBlank()) {
                return productNameFr.trim();
            }
            return productName != null ? productName.trim() : null;
        }

        /** Premiere marque citee (le champ en contient parfois plusieurs). */
        public String firstBrand() {
            if (brands == null || brands.isBlank()) {
                return null;
            }
            String first = brands.split(",")[0].trim();
            return first.isEmpty() ? null : first;
        }

        public Double calories() {
            return nutriments != null ? nutriments.resolvedEnergyKcal() : null;
        }

        public Double protein() {
            return nutriments != null ? nutriments.proteins() : null;
        }

        public Double carbs() {
            return nutriments != null ? nutriments.carbohydrates() : null;
        }

        public Double fat() {
            return nutriments != null ? nutriments.fat() : null;
        }

        public Double fiber() {
            return nutriments != null ? nutriments.fiber() : null;
        }

        /**
         * Exploitable dans un journal alimentaire.
         *
         * <p>OFF accepte des fiches incompletes : un produit peut n'avoir
         * qu'une photo et un code-barres. Sans nom ou sans la moindre macro,
         * il n'a rien a faire dans les resultats de recherche.
         */
        public boolean isUsable() {
            String name = resolvedName();
            return code != null && !code.isBlank()
                    && name != null && !name.isBlank()
                    && (calories() != null || protein() != null
                    || carbs() != null || fat() != null);
        }
    }

    /**
     * Nutriments pour 100 g.
     *
     * <p><b>Piege de l'energie.</b> OFF expose {@code energy-kcal_100g} sur les
     * fiches recentes, mais les plus anciennes ne portent que
     * {@code energy_100g}, exprime en <b>kilojoules</b>. Sans repli, ces
     * produits s'afficheraient a 0 kcal.
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Nutriments(
            @JsonProperty("energy-kcal_100g") Double energyKcal100g,
            @JsonProperty("energy_100g") Double energy100g,
            @JsonProperty("proteins_100g") Double proteins,
            @JsonProperty("carbohydrates_100g") Double carbohydrates,
            @JsonProperty("fat_100g") Double fat,
            @JsonProperty("fiber_100g") Double fiber
    ) {

        /** Facteur de conversion kilojoules -> kilocalories. */
        private static final double KJ_PER_KCAL = 4.184;

        /** Energie en kcal, avec repli sur la valeur en kJ des fiches anciennes. */
        public Double resolvedEnergyKcal() {
            if (energyKcal100g != null) {
                return energyKcal100g;
            }
            if (energy100g == null) {
                return null;
            }
            return Math.round(energy100g / KJ_PER_KCAL * 10.0) / 10.0;
        }
    }
}
