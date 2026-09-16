package com.fitforge.api.nutrition.ai.service;

import com.fitforge.api.nutrition.ai.client.GeminiDtos;
import com.fitforge.api.nutrition.ai.dto.AnalyzedFoodDto;
import com.fitforge.api.nutrition.dto.FoodSearchResultDto;
import com.fitforge.api.nutrition.service.FoodCatalogService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * Du <b>nom d'aliment</b> aux <b>macros</b>.
 *
 * <p>Etage commun aux deux entrees d'analyse automatique : la photo de repas
 * ({@code nutrition/vision}) et la description vocale ({@code nutrition/voice}).
 * Toutes deux aboutissent a la meme chose — une liste de noms d'aliments en
 * francais avec une quantite estimee — et doivent ensuite subir exactement le
 * meme traitement : dedoublonnage, plafonnement, recherche au catalogue,
 * calcul au prorata, totaux.
 *
 * <p>Ce composant ne reimplemente <b>aucune</b> logique nutritionnelle : il
 * s'appuie sur {@link FoodCatalogService}, qui sait deja traduire FR -&gt; EN
 * par le lexique culinaire, lire le cache local, interroger USDA puis Open
 * Food Facts.
 *
 * <p><b>Degradation gracieuse a chaque etage.</b> Un aliment introuvable au
 * catalogue est renvoye <b>marque non resolu</b> plutot que supprime :
 * l'adherent voit que le modele l'a bien compris, et peut le saisir a la main.
 * Une recherche en panne n'annule que cet aliment-la, pas les autres.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class DetectedFoodResolver {

    /**
     * Plafond d'aliments traites. Chaque aliment declenche une recherche
     * catalogue (donc potentiellement un appel USDA puis Open Food Facts) :
     * sans borne, une photo de buffet ou un monologue de trois minutes
     * feraient exploser la latence et les quotas.
     */
    public static final int MAX_FOODS = 12;

    /**
     * Tentatives de recherche par aliment (libelle complet, puis raccourci).
     * Chaque tentative peut couter un appel externe : on plafonne.
     */
    private static final int MAX_SEARCH_ATTEMPTS = 3;

    private final FoodCatalogService foodCatalog;

    /**
     * Resout une liste d'aliments detectes : dedoublonne, plafonne, puis
     * cherche chacun au catalogue.
     *
     * @param detected ce que le modele a compris, dans son ordre
     * @return les aliments enrichis, dans le meme ordre
     */
    public List<AnalyzedFoodDto> resolveAll(List<GeminiDtos.DetectedFood> detected) {
        List<AnalyzedFoodDto> foods = new ArrayList<>();
        Set<String> seen = new LinkedHashSet<>();

        for (GeminiDtos.DetectedFood food : detected) {
            if (foods.size() >= MAX_FOODS) {
                break;
            }
            // Le modele repete parfois le meme aliment (deux morceaux de pain
            // sur l'assiette, « du pain, et aussi du pain grille ») : on ne le
            // propose qu'une fois.
            if (!seen.add(food.name().trim().toLowerCase(Locale.FRENCH))) {
                continue;
            }
            foods.add(resolve(food));
        }
        return foods;
    }

    // ── Resolution d'un aliment ──────────────────────────────────────

    /** Cherche l'aliment au catalogue et calcule ses macros au prorata. */
    private AnalyzedFoodDto resolve(GeminiDtos.DetectedFood detected) {
        String label = detected.name().trim();
        double grams = detected.grams();

        FoodSearchResultDto match = bestMatch(label);
        if (match == null) {
            // Aliment compris mais introuvable, meme apres USDA et Open Food
            // Facts : on le renvoie quand meme, non resolu, plutot que de le
            // faire disparaitre sans explication.
            return new AnalyzedFoodDto(
                    label, round(grams, 1), detected.confidence(), false,
                    null, null, null, null,
                    null, null, null, null, null,
                    null, null, null, null, null);
        }

        double ratio = grams / 100.0;
        return new AnalyzedFoodDto(
                label,
                round(grams, 1),
                detected.confidence(),
                true,
                match.name(),
                match.foodItemId(),
                match.fdcId(),
                match.offCode(),
                scaleToInt(match.caloriesPer100g(), ratio),
                scale(match.proteinPer100g(), ratio),
                scale(match.carbsPer100g(), ratio),
                scale(match.fatPer100g(), ratio),
                scale(match.fiberPer100g(), ratio),
                match.caloriesPer100g(),
                match.proteinPer100g(),
                match.carbsPer100g(),
                match.fatPer100g(),
                match.fiberPer100g());
    }

    /**
     * Meilleur resultat du catalogue pour un libelle detecte.
     *
     * <p>{@code search} fait deja l'essentiel : cache local, traduction
     * FR -&gt; EN par le lexique, USDA, puis Open Food Facts si USDA est muet.
     * On garde le premier resultat, le plus pertinent.
     *
     * <p><b>Repli par raccourcissement.</b> Un modele decrit un plat, pas une
     * entree de base de donnees : il renvoie « saumon grille » ou « pommes de
     * terre sautees ». Or la recherche USDA exige la presence de <i>tous</i>
     * les mots — « grilled » n'apparait dans aucun libelle USDA, et la
     * recherche echoue alors que l'aliment existe. On retire donc les
     * qualificatifs <b>par la droite</b>, ce qui correspond a la construction
     * du francais (nom de tete d'abord, qualificatifs ensuite) :
     *
     * <pre>
     *   « pommes de terre sautees »  ->  « pommes de terre »  ->  « pommes »
     *      ^ echoue                        ^ trouve
     * </pre>
     *
     * Retirer par la gauche donnerait « terre sautees », un contresens. Le
     * nombre de tentatives est borne : chacune peut couter un appel externe.
     *
     * <p>Une recherche en echec ne doit pas faire tomber toute l'analyse : les
     * autres aliments du repas restent exploitables.
     */
    private FoodSearchResultDto bestMatch(String label) {
        for (String candidate : shrinkingCandidates(label)) {
            try {
                List<FoodSearchResultDto> results = foodCatalog.search(candidate);
                if (!results.isEmpty()) {
                    return results.get(0);
                }
            } catch (RuntimeException e) {
                // Catalogue indisponible (quota USDA, reseau) : inutile
                // d'insister avec les variantes, elles echoueront pareil.
                log.warn("Analyse : recherche catalogue indisponible pour « {} » ({})",
                        label, e.getMessage());
                return null;
            }
        }
        return null;
    }

    /**
     * Le libelle, puis ses versions raccourcies par la droite.
     *
     * <p>Le plafond de {@link #MAX_SEARCH_ATTEMPTS} essais protege aussi contre
     * le seul cas dangereux du procede : reduire un nom compose a son premier
     * mot. « pommes de terre sautees » descend jusqu'a « pommes de terre »
     * (3 essais atteints) et <b>jamais</b> jusqu'a « pommes », qui serait
     * traduit par « apple » — un faux positif pire qu'une absence de resultat.
     * Les libelles courts, eux, doivent pouvoir tomber a un seul mot :
     * « saumon grille » n'a de chance d'aboutir qu'en « saumon ».
     */
    private List<String> shrinkingCandidates(String label) {
        String[] words = label.trim().split("\\s+");
        List<String> candidates = new ArrayList<>(MAX_SEARCH_ATTEMPTS);

        for (int size = words.length; size >= 1 && candidates.size() < MAX_SEARCH_ATTEMPTS; size--) {
            candidates.add(String.join(" ", Arrays.copyOfRange(words, 0, size)));
        }
        return candidates;
    }

    // ── Totaux ───────────────────────────────────────────────────────

    /**
     * Additionne les seuls aliments resolus.
     *
     * <p>Compter des macros inconnues comme des zeros donnerait un total
     * faussement rassurant : l'adherent croirait avoir mange 400 kcal alors
     * qu'un aliment non reconnu n'est simplement pas comptabilise.
     */
    public Totals total(List<AnalyzedFoodDto> foods) {
        int matched = 0;
        int calories = 0;
        double protein = 0;
        double carbs = 0;
        double fat = 0;
        double fiber = 0;

        for (AnalyzedFoodDto f : foods) {
            if (!f.matched()) {
                continue;
            }
            matched++;
            calories += f.calories() != null ? f.calories() : 0;
            protein += f.proteinG() != null ? f.proteinG() : 0;
            carbs += f.carbsG() != null ? f.carbsG() : 0;
            fat += f.fatG() != null ? f.fatG() : 0;
            fiber += f.fiberG() != null ? f.fiberG() : 0;
        }

        return new Totals(matched, calories,
                round(protein, 1), round(carbs, 1), round(fat, 1), round(fiber, 1));
    }

    /** Totaux d'une analyse, sur les seuls aliments retrouves au catalogue. */
    public record Totals(
            int matchedCount,
            int calories,
            double proteinG,
            double carbsG,
            double fatG,
            double fiberG
    ) {
    }

    // ── Calculs ──────────────────────────────────────────────────────

    /** Macro au prorata, arrondie a 1 decimale. {@code null} reste {@code null}. */
    private Double scale(Double per100g, double ratio) {
        return per100g == null ? null : round(per100g * ratio, 1);
    }

    /** Calories au prorata, arrondies a l'entier (jamais negatives). */
    private Integer scaleToInt(Double per100g, double ratio) {
        return per100g == null ? null : (int) Math.max(0, Math.round(per100g * ratio));
    }

    private double round(double value, int decimals) {
        return BigDecimal.valueOf(value).setScale(decimals, RoundingMode.HALF_UP).doubleValue();
    }
}
