package com.fitforge.api.nutrition.i18n;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests du lexique culinaire FR &lt;-&gt; EN.
 *
 * <p>Pas de contexte Spring : {@link FoodLexicon} ne depend que de son fichier
 * de ressources, ces tests s'executent donc en quelques millisecondes.
 *
 * <p>Ils protegent surtout les <b>regles d'appariement</b> (expressions les
 * plus longues d'abord, pluriels, accents, articles) : ce sont elles qui
 * cassent silencieusement quand on enrichit le lexique.
 */
class FoodLexiconTest {

    private final FoodLexicon lexicon = new FoodLexicon();

    // ── Sens FR -> EN : la recherche ──────────────────────────────────

    @ParameterizedTest(name = "« {0} » -> « {1} »")
    @DisplayName("La saisie francaise est traduite pour USDA")
    @CsvSource({
            "poulet,                chicken",
            "riz,                   rice",
            "banane,                banana",
            "yaourt,                yogurt",
            "oeuf,                  egg",
            "saumon,                salmon",
            "amandes,               almond",       // pluriel
            "cereales,              cereal",       // sans accent
            "céréales,              cereal",       // avec accent
            "bœuf,                  beef",         // ligature
            "boeuf,                 beef"          // ligature ecrite en deux lettres
    })
    void translatesFrenchSearchTerms(String french, String expected) {
        assertThat(lexicon.toEnglishQuery(french)).isEqualTo(expected);
    }

    @Test
    @DisplayName("Les expressions l'emportent sur les mots isoles")
    void prefersLongestPhrase() {
        // « pomme de terre » ne doit surtout pas devenir « apple of earth ».
        assertThat(lexicon.toEnglishQuery("pomme de terre")).isEqualTo("potato");
        assertThat(lexicon.toEnglishQuery("blanc de poulet")).isEqualTo("chicken breast");
        assertThat(lexicon.toEnglishQuery("huile d'olive")).isEqualTo("olive oil");
    }

    @Test
    @DisplayName("Les articles residuels sont retires de la requete")
    void dropsLeftoverArticles() {
        // « de » n'est absorbe par aucune expression ici : il ne doit pas
        // partir vers USDA, qui exige la presence de TOUS les mots.
        assertThat(lexicon.toEnglishQuery("filet de saumon")).isEqualTo("fillet salmon");
    }

    @Test
    @DisplayName("Une saisie deja anglaise traverse intacte")
    void leavesEnglishQueryUntouched() {
        assertThat(lexicon.toEnglishQuery("chicken breast")).isEqualTo("chicken breast");
    }

    @Test
    @DisplayName("Un terme inconnu (marque, plat exotique) traverse intact")
    void leavesUnknownQueryUntouched() {
        assertThat(lexicon.toEnglishQuery("Nutella")).isEqualTo("Nutella");
        assertThat(lexicon.toEnglishQuery("Skyr Danone")).isEqualTo("Skyr Danone");
    }

    // ── Sens EN -> FR : l'affichage ───────────────────────────────────

    @Test
    @DisplayName("Un libelle USDA complet devient lisible en francais")
    void translatesFullUsdaLabel() {
        assertThat(lexicon.toFrenchLabel("Chicken, broiler or fryer, breast, meat only, raw"))
                .isEqualTo("Poulet, de chair, blanc, viande seule, cru");

        assertThat(lexicon.toFrenchLabel("Egg, whole, raw, fresh"))
                .isEqualTo("Œuf, entier, cru, frais");

        assertThat(lexicon.toFrenchLabel("Rice, white, long-grain, regular, cooked"))
                .isEqualTo("Riz, blanc, grain long, classique, cuit");
    }

    @Test
    @DisplayName("Le pluriel anglais retombe sur le singulier francais")
    void handlesEnglishPlurals() {
        // Choix assume : on renvoie le SINGULIER. Un lexique ignore le genre
        // grammatical, il ne peut donc pas accorder les descripteurs qui
        // suivent : « Banane, cru » reste coherent la ou « Bananes, cru »
        // serait fautif. Un libelle de journal alimentaire est de toute facon
        // telegraphique, comme l'original USDA.
        assertThat(lexicon.toFrenchLabel("Bananas, raw")).isEqualTo("Banane, cru");
        assertThat(lexicon.toFrenchLabel("Tomatoes, red, ripe, raw"))
                .isEqualTo("Tomate, rouge, mûr, cru");
    }

    @Test
    @DisplayName("La premiere lettre du libelle est toujours en majuscule")
    void capitalizesLabel() {
        assertThat(lexicon.toFrenchLabel("cheese, cheddar")).isEqualTo("Fromage, cheddar");
    }

    @Test
    @DisplayName("Un terme inconnu reste affiche tel quel, sans casser le libelle")
    void keepsUnknownTermsInLabel() {
        assertThat(lexicon.toFrenchLabel("Kombucha, raw")).isEqualTo("Kombucha, cru");
    }

    @Test
    @DisplayName("Un separateur isole n'est jamais avale par une expression")
    void keepsStandaloneSeparators() {
        // Regression : « lean meat » etait apparie a travers le « / », qui
        // disparaissait du libelle et faussait la lecture du ratio.
        assertThat(lexicon.toFrenchLabel("Beef, ground, 85% lean meat / 15% fat, raw"))
                .isEqualTo("Bœuf, haché, 85% viande maigre / 15% gras, cru");
    }

    // ── Robustesse ────────────────────────────────────────────────────

    @Test
    @DisplayName("Les entrees vides ou nulles ne font jamais echouer")
    void toleratesEmptyInput() {
        assertThat(lexicon.toEnglishQuery(null)).isNull();
        assertThat(lexicon.toFrenchLabel(null)).isNull();
        assertThat(lexicon.toEnglishQuery("   ")).isEqualTo("   ");
        assertThat(lexicon.toFrenchLabel("")).isEmpty();
    }

    @Test
    @DisplayName("Le lexique est bien charge depuis les ressources")
    void loadsLexiconResource() {
        // Garde-fou : un fichier absent ou mal encode ferait passer toutes les
        // traductions en identite, ce que les tests ci-dessus detecteraient mal
        // si le lexique venait a disparaitre du jar.
        assertThat(lexicon.toEnglishQuery("poulet")).isNotEqualTo("poulet");
    }
}
