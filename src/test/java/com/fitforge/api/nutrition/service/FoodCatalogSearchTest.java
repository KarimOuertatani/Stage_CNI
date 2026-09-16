package com.fitforge.api.nutrition.service;

import com.fitforge.api.common.enums.FoodResultSource;
import com.fitforge.api.common.enums.FoodSource;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.nutrition.client.OpenFoodFactsClient;
import com.fitforge.api.nutrition.client.OpenFoodFactsDtos;
import com.fitforge.api.nutrition.client.UsdaApiClient;
import com.fitforge.api.nutrition.client.UsdaDtos;
import com.fitforge.api.nutrition.dto.FoodSearchResultDto;
import com.fitforge.api.nutrition.entity.FoodItem;
import com.fitforge.api.nutrition.i18n.FoodLexicon;
import com.fitforge.api.nutrition.repository.FoodItemRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.Pageable;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Tests de la recherche multi-sources : <b>cache local -&gt; USDA -&gt; Open
 * Food Facts</b>.
 *
 * <p>Le point sensible n'est pas le cas nominal mais l'<b>ordre</b> et les
 * <b>bascules</b> : Open Food Facts ne doit couter un appel reseau que
 * lorsqu'il est reellement utile, et l'echec d'une source ne doit jamais
 * empecher une autre de repondre.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class FoodCatalogSearchTest {

    @Mock
    private FoodItemRepository foodRepo;
    @Mock
    private UsdaApiClient usda;
    @Mock
    private OpenFoodFactsClient openFoodFacts;
    @Mock
    private FoodLexicon lexicon;

    private FoodCatalogService service;

    @BeforeEach
    void setUp() {
        service = new FoodCatalogService(foodRepo, usda, openFoodFacts, lexicon);

        // Par defaut : lexique neutre, catalogue local vide, sources muettes.
        when(lexicon.toEnglishQuery(anyString())).thenAnswer(i -> i.getArgument(0));
        when(lexicon.toFrenchLabel(anyString())).thenAnswer(i -> i.getArgument(0));
        when(foodRepo.searchByName(anyString(), anyString(), any(Pageable.class)))
                .thenReturn(List.of());
        when(foodRepo.findByUsdaFdcIdIn(any())).thenReturn(List.of());
        when(foodRepo.findByOffCodeIn(any())).thenReturn(List.of());
        when(usda.searchFoods(anyString())).thenReturn(List.of());
        when(openFoodFacts.searchProducts(anyString())).thenReturn(List.of());
    }

    // ── Fixtures ─────────────────────────────────────────────────────

    private UsdaDtos.Food usdaFood(long fdcId, String description, double kcal) {
        return new UsdaDtos.Food(
                fdcId, description, "SR Legacy", null, null,
                List.of(new UsdaDtos.Nutrient(
                        UsdaDtos.NUTRIENT_ENERGY_KCAL, kcal, null, null)));
    }

    private OpenFoodFactsDtos.Product offProduct(String code, String name, String brand) {
        return new OpenFoodFactsDtos.Product(
                code, name, name, brand,
                new OpenFoodFactsDtos.Nutriments(59.0, null, 4.0, 4.5, 2.8, null));
    }

    private FoodItem cachedItem(String name) {
        return FoodItem.builder()
                .id(UUID.randomUUID())
                .name(name)
                .nameFr(name)
                .usdaFdcId(171077L)
                .source(FoodSource.USDA)
                .caloriesPer100g(89.0)
                .build();
    }

    // ── Le cas qui motive Open Food Facts ────────────────────────────

    @Test
    @DisplayName("USDA muet sur un produit de marque : Open Food Facts prend le relais")
    void fallsBackToOpenFoodFactsWhenUsdaFindsNothing() {
        when(usda.searchFoods(anyString())).thenReturn(List.of());
        when(openFoodFacts.searchProducts("skyr nature"))
                .thenReturn(List.of(offProduct("3033710065967", "Skyr nature", "Danone")));

        List<FoodSearchResultDto> results = service.search("skyr nature");

        assertThat(results).hasSize(1);
        FoodSearchResultDto found = results.get(0);
        assertThat(found.name()).isEqualTo("Skyr nature");
        assertThat(found.brand()).isEqualTo("Danone");
        assertThat(found.source()).isEqualTo(FoodResultSource.OPEN_FOOD_FACTS);
        // C'est le code-barres, et lui seul, que l'app renverra a /from-food.
        assertThat(found.offCode()).isEqualTo("3033710065967");
        assertThat(found.fdcId()).isNull();
        assertThat(found.cached()).isFalse();
        assertThat(found.caloriesPer100g()).isEqualTo(59.0);
    }

    @Test
    @DisplayName("Une panne USDA n'empeche pas Open Food Facts de repondre")
    void usdaOutageStillLetsOpenFoodFactsAnswer() {
        when(usda.searchFoods(anyString()))
                .thenThrow(new BusinessException("Quota de recherche atteint"));
        when(openFoodFacts.searchProducts("nutella"))
                .thenReturn(List.of(offProduct("3017620422003", "Nutella", "Ferrero")));

        List<FoodSearchResultDto> results = service.search("nutella");

        assertThat(results).hasSize(1);
        assertThat(results.get(0).source()).isEqualTo(FoodResultSource.OPEN_FOOD_FACTS);
    }

    // ── Aucune source ne trouve rien ─────────────────────────────────

    @Test
    @DisplayName("Aucune source ne trouve rien : liste vide, jamais une exception")
    void nothingFoundAnywhereReturnsEmptyList() {
        List<FoodSearchResultDto> results = service.search("xyzabc introuvable");

        assertThat(results).isEmpty();
        // Les trois sources ont bien ete sollicitees dans l'ordre.
        verify(foodRepo).searchByName(anyString(), anyString(), any(Pageable.class));
        verify(usda).searchFoods("xyzabc introuvable");
        verify(openFoodFacts).searchProducts("xyzabc introuvable");
    }

    @Test
    @DisplayName("USDA en panne ET rien ailleurs : l'erreur reelle est remontee")
    void usdaErrorSurfacesWhenNoSourceCanCompensate() {
        when(usda.searchFoods(anyString()))
                .thenThrow(new BusinessException("Quota de recherche atteint"));

        assertThatThrownBy(() -> service.search("poulet"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Quota");
    }

    // ── Open Food Facts reste une source de dernier recours ──────────

    @Test
    @DisplayName("USDA a repondu : Open Food Facts n'est meme pas appele")
    void openFoodFactsIsNotCalledWhenUsdaAnswers() {
        when(usda.searchFoods(anyString()))
                .thenReturn(List.of(usdaFood(173944L, "Bananas, raw", 89.0)));

        List<FoodSearchResultDto> results = service.search("banane");

        assertThat(results).hasSize(1);
        assertThat(results.get(0).source()).isEqualTo(FoodResultSource.USDA);
        // Le point du test : pas d'appel reseau superflu.
        verify(openFoodFacts, never()).searchProducts(anyString());
    }

    @Test
    @DisplayName("Un terme trop court n'appelle aucune source externe")
    void shortQueryCallsNothing() {
        assertThat(service.search("a")).isEmpty();

        verify(usda, never()).searchFoods(anyString());
        verify(openFoodFacts, never()).searchProducts(anyString());
    }

    // ── Le cache passe devant ────────────────────────────────────────

    @Test
    @DisplayName("Le cache local est propose en tete, marque LOCAL")
    void localCacheComesFirst() {
        when(foodRepo.searchByName(anyString(), anyString(), any(Pageable.class)))
                .thenReturn(List.of(cachedItem("Banane, cru")));
        when(usda.searchFoods(anyString()))
                .thenReturn(List.of(usdaFood(999L, "Banana bread", 320.0)));

        List<FoodSearchResultDto> results = service.search("banane");

        assertThat(results).hasSize(2);
        assertThat(results.get(0).source()).isEqualTo(FoodResultSource.LOCAL);
        assertThat(results.get(0).foodItemId()).isNotNull();
        assertThat(results.get(1).source()).isEqualTo(FoodResultSource.USDA);
    }

    @Test
    @DisplayName("Un aliment deja en cache n'est pas propose deux fois")
    void cachedFoodIsNotDuplicatedByUsda() {
        FoodItem cached = cachedItem("Oeuf, entier, cru");
        when(foodRepo.searchByName(anyString(), anyString(), any(Pageable.class)))
                .thenReturn(List.of(cached));
        // USDA renvoie le MEME aliment (meme fdcId) que celui deja en cache.
        when(usda.searchFoods(anyString()))
                .thenReturn(List.of(usdaFood(171077L, "Egg, whole, raw", 143.0)));

        List<FoodSearchResultDto> results = service.search("oeuf");

        assertThat(results).hasSize(1);
        assertThat(results.get(0).source()).isEqualTo(FoodResultSource.LOCAL);
    }

    @Test
    @DisplayName("Un produit Open Food Facts deja importe ressort en LOCAL")
    void alreadyImportedOffProductComesBackAsLocal() {
        FoodItem imported = FoodItem.builder()
                .id(UUID.randomUUID())
                .name("Skyr nature")
                .nameFr("Skyr nature")
                .offCode("3033710065967")
                .source(FoodSource.OPEN_FOOD_FACTS)
                .caloriesPer100g(59.0)
                .build();

        when(openFoodFacts.searchProducts(anyString()))
                .thenReturn(List.of(offProduct("3033710065967", "Skyr nature", "Danone")));
        when(foodRepo.findByOffCodeIn(any())).thenReturn(List.of(imported));

        List<FoodSearchResultDto> results = service.search("skyr");

        assertThat(results).hasSize(1);
        // Deja en cache : ajout instantane, aucun appel externe a la validation.
        assertThat(results.get(0).source()).isEqualTo(FoodResultSource.LOCAL);
        assertThat(results.get(0).foodItemId()).isEqualTo(imported.getId());
    }

    // ── Import et mise en cache ──────────────────────────────────────

    @Test
    @DisplayName("Un produit Open Food Facts est importe puis mis en cache")
    void importsAndCachesOpenFoodFactsProduct() {
        when(foodRepo.findByOffCode("3033710065967")).thenReturn(Optional.empty());
        when(openFoodFacts.findByCode("3033710065967"))
                .thenReturn(Optional.of(offProduct("3033710065967", "Skyr nature", "Danone")));
        when(foodRepo.saveAndFlush(any(FoodItem.class))).thenAnswer(i -> i.getArgument(0));

        FoodItem saved = service.resolveOrImport(null, null, "3033710065967");

        assertThat(saved.getOffCode()).isEqualTo("3033710065967");
        assertThat(saved.getSource()).isEqualTo(FoodSource.OPEN_FOOD_FACTS);
        assertThat(saved.getUsdaFdcId()).isNull();
        assertThat(saved.getCaloriesPer100g()).isEqualTo(59.0);
        // Le libelle OFF est deja francais : il ne passe pas par le lexique.
        assertThat(saved.getNameFr()).isEqualTo("Skyr nature");
        verify(foodRepo).saveAndFlush(any(FoodItem.class));
    }

    @Test
    @DisplayName("Un produit deja en cache ne declenche aucun appel Open Food Facts")
    void cachedOffProductSkipsTheExternalCall() {
        FoodItem cached = FoodItem.builder()
                .id(UUID.randomUUID())
                .name("Skyr nature")
                .offCode("3033710065967")
                .source(FoodSource.OPEN_FOOD_FACTS)
                .build();
        when(foodRepo.findByOffCode("3033710065967")).thenReturn(Optional.of(cached));

        assertThat(service.resolveOrImport(null, null, "3033710065967")).isSameAs(cached);

        verify(openFoodFacts, never()).findByCode(anyString());
        verify(foodRepo, never()).saveAndFlush(any(FoodItem.class));
    }

    @Test
    @DisplayName("Un code-barres disparu de la base donne un message actionnable")
    void vanishedBarcodeGivesAClearMessage() {
        when(foodRepo.findByOffCode(anyString())).thenReturn(Optional.empty());
        when(openFoodFacts.findByCode(anyString())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.resolveOrImport(null, null, "0000000000000"))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("manuellement");
    }

    @Test
    @DisplayName("Sans aucun identifiant, l'import est refuse")
    void noIdentifierIsRejected() {
        assertThatThrownBy(() -> service.resolveOrImport(null, null, null))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Aucun aliment");
    }
}
