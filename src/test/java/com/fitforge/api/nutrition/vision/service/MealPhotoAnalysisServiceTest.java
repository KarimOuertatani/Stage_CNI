package com.fitforge.api.nutrition.vision.service;

import com.fitforge.api.common.enums.FoodResultSource;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.nutrition.ai.client.GeminiDtos;
import com.fitforge.api.nutrition.ai.dto.AnalyzedFoodDto;
import com.fitforge.api.nutrition.ai.service.DetectedFoodResolver;
import com.fitforge.api.nutrition.dto.FoodSearchResultDto;
import com.fitforge.api.nutrition.service.FoodCatalogService;
import com.fitforge.api.nutrition.vision.client.GeminiVisionClient;
import com.fitforge.api.nutrition.vision.dto.PhotoAnalysisResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Tests de l'analyse de photo de repas.
 *
 * <p>L'accent est mis sur les <b>cas degrades</b>, qui sont la vraie difficulte
 * ici : un modele de vision se trompe, un aliment peut ne pas exister au
 * catalogue, et le service externe peut tomber. Aucun de ces cas ne doit faire
 * echouer toute l'analyse ni exposer une erreur technique a l'adherent.
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class MealPhotoAnalysisServiceTest {

    @Mock
    private GeminiVisionClient gemini;
    @Mock
    private FoodCatalogService foodCatalog;

    private MealPhotoAnalysisService service;

    @BeforeEach
    void setUp() {
        // Le resolveur est le VRAI composant : c'est lui qui porte le calcul au
        // prorata et le dedoublonnage, on veut donc l'exercer. Seuls le modele
        // et le catalogue sont simules.
        service = new MealPhotoAnalysisService(gemini, new DetectedFoodResolver(foodCatalog));
        // Champ @Value, non injecte hors contexte Spring.
        ReflectionTestUtils.setField(service, "maxImageBytes", 8L * 1024 * 1024);
    }

    private MockMultipartFile photo() {
        return new MockMultipartFile("file", "repas.jpg", "image/jpeg", new byte[]{1, 2, 3});
    }

    private FoodSearchResultDto catalogHit(String name, double kcal, double protein) {
        return new FoodSearchResultDto(
                UUID.randomUUID(), 171077L, null, name, null, "SR Legacy",
                FoodResultSource.LOCAL, true,
                kcal, protein, 0.0, 3.6, null);
    }

    // ── Cas nominal ──────────────────────────────────────────────────

    @Test
    @DisplayName("Les macros sont calculees au prorata de la quantite estimee")
    void computesMacrosProRata() {
        when(gemini.detectFoods(any(), anyString()))
                .thenReturn(List.of(new GeminiDtos.DetectedFood("blanc de poulet", 150.0, 0.9)));
        when(foodCatalog.search("blanc de poulet"))
                .thenReturn(List.of(catalogHit("Poulet, blanc, cru", 110.0, 23.0)));

        PhotoAnalysisResponse response = service.analyze(photo());

        AnalyzedFoodDto food = response.foods().get(0);
        assertThat(food.matched()).isTrue();
        // 110 kcal/100 g x 150 g = 165 kcal ; 23 g/100 g x 150 g = 34,5 g
        assertThat(food.calories()).isEqualTo(165);
        assertThat(food.proteinG()).isEqualTo(34.5);
        assertThat(response.totalCalories()).isEqualTo(165);
        assertThat(response.matchedCount()).isEqualTo(1);
    }

    @Test
    @DisplayName("Les valeurs pour 100 g sont renvoyees pour le recalcul cote app")
    void exposesPer100gValues() {
        when(gemini.detectFoods(any(), anyString()))
                .thenReturn(List.of(new GeminiDtos.DetectedFood("riz blanc", 200.0, 0.8)));
        when(foodCatalog.search(anyString()))
                .thenReturn(List.of(catalogHit("Riz, blanc, cuit", 130.0, 2.7)));

        AnalyzedFoodDto food = service.analyze(photo()).foods().get(0);

        assertThat(food.caloriesPer100g()).isEqualTo(130.0);
        assertThat(food.proteinPer100g()).isEqualTo(2.7);
    }

    // ── Aucune detection ─────────────────────────────────────────────

    @Test
    @DisplayName("Une photo sans aliment renvoie une liste vide, jamais une erreur")
    void noDetectionReturnsEmpty() {
        when(gemini.detectFoods(any(), anyString())).thenReturn(List.of());

        PhotoAnalysisResponse response = service.analyze(photo());

        assertThat(response.foods()).isEmpty();
        assertThat(response.detectedCount()).isZero();
        assertThat(response.totalCalories()).isZero();
        // Aucun aliment detecte : inutile d'aller interroger le catalogue.
        verify(foodCatalog, never()).search(anyString());
    }

    // ── Aliment introuvable ──────────────────────────────────────────

    @Test
    @DisplayName("Un aliment introuvable est conserve, marque non resolu")
    void unmatchedFoodIsKeptButFlagged() {
        when(gemini.detectFoods(any(), anyString()))
                .thenReturn(List.of(new GeminiDtos.DetectedFood("bricks tunisiennes", 90.0, 0.6)));
        when(foodCatalog.search(anyString())).thenReturn(List.of());

        PhotoAnalysisResponse response = service.analyze(photo());

        AnalyzedFoodDto food = response.foods().get(0);
        assertThat(food.matched()).isFalse();
        assertThat(food.detectedLabel()).isEqualTo("bricks tunisiennes");
        assertThat(food.calories()).isNull();
        assertThat(food.foodItemId()).isNull();
        assertThat(food.fdcId()).isNull();
        // Il a bien ete vu, mais ne compte pas dans les totaux.
        assertThat(response.detectedCount()).isEqualTo(1);
        assertThat(response.matchedCount()).isZero();
        assertThat(response.totalCalories()).isZero();
    }

    @Test
    @DisplayName("Une recherche catalogue en panne n'annule pas les autres aliments")
    void catalogFailureDoesNotAbortAnalysis() {
        when(gemini.detectFoods(any(), anyString())).thenReturn(List.of(
                new GeminiDtos.DetectedFood("brocoli", 80.0, 0.9),
                new GeminiDtos.DetectedFood("riz blanc", 150.0, 0.9)));
        when(foodCatalog.search("brocoli"))
                .thenThrow(new BusinessException("Quota USDA atteint"));
        when(foodCatalog.search("riz blanc"))
                .thenReturn(List.of(catalogHit("Riz, blanc, cuit", 130.0, 2.7)));

        PhotoAnalysisResponse response = service.analyze(photo());

        assertThat(response.foods()).hasSize(2);
        assertThat(response.foods().get(0).matched()).isFalse();  // brocoli : recherche KO
        assertThat(response.foods().get(1).matched()).isTrue();   // riz : intact
        assertThat(response.matchedCount()).isEqualTo(1);
    }

    // ── Panne du service d'analyse ───────────────────────────────────

    @Test
    @DisplayName("Une panne Gemini remonte telle quelle, avec son message metier")
    void geminiFailurePropagates() {
        when(gemini.detectFoods(any(), anyString()))
                .thenThrow(new BusinessException(
                        "L'analyse de photo est momentanement injoignable. Reessayez dans un instant."));

        assertThatThrownBy(() -> service.analyze(photo()))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("injoignable");
    }

    // ── Fichier invalide ─────────────────────────────────────────────

    @Test
    @DisplayName("Un fichier vide est refuse avant tout appel externe")
    void emptyFileIsRejected() {
        MockMultipartFile empty =
                new MockMultipartFile("file", "vide.jpg", "image/jpeg", new byte[0]);

        assertThatThrownBy(() -> service.analyze(empty))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Aucune photo");

        verify(gemini, never()).detectFoods(any(), anyString());
    }

    @Test
    @DisplayName("Un fichier qui n'est pas une image est refuse")
    void nonImageIsRejected() {
        MockMultipartFile pdf = new MockMultipartFile(
                "file", "facture.pdf", "application/pdf", new byte[]{1, 2, 3});

        assertThatThrownBy(() -> service.analyze(pdf))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("image");

        verify(gemini, never()).detectFoods(any(), anyString());
    }

    @Test
    @DisplayName("Une photo trop volumineuse est refusee avant encodage")
    void oversizedPhotoIsRejected() {
        ReflectionTestUtils.setField(service, "maxImageBytes", 10L);
        MockMultipartFile big = new MockMultipartFile(
                "file", "grande.jpg", "image/jpeg", new byte[64]);

        assertThatThrownBy(() -> service.analyze(big))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("volumineuse");

        verify(gemini, never()).detectFoods(any(), anyString());
    }

    // ── Robustesse du modele ─────────────────────────────────────────

    @Test
    @DisplayName("Un aliment repete n'est propose qu'une fois")
    void deduplicatesRepeatedFoods() {
        when(gemini.detectFoods(any(), anyString())).thenReturn(List.of(
                new GeminiDtos.DetectedFood("pain", 40.0, 0.8),
                new GeminiDtos.DetectedFood("Pain", 40.0, 0.7)));
        when(foodCatalog.search(anyString()))
                .thenReturn(List.of(catalogHit("Pain, blanc", 265.0, 9.0)));

        PhotoAnalysisResponse response = service.analyze(photo());

        assertThat(response.foods()).hasSize(1);
    }

    @Test
    @DisplayName("Le nombre d'aliments traites est plafonne")
    void capsNumberOfFoods() {
        // 20 aliments detectes : chacun declencherait une recherche catalogue,
        // donc potentiellement un appel USDA. On en traite au plus 12.
        List<GeminiDtos.DetectedFood> many = new java.util.ArrayList<>();
        for (int i = 0; i < 20; i++) {
            many.add(new GeminiDtos.DetectedFood("aliment " + i, 50.0, 0.5));
        }
        when(gemini.detectFoods(any(), anyString())).thenReturn(many);
        when(foodCatalog.search(anyString())).thenReturn(List.of());

        PhotoAnalysisResponse response = service.analyze(photo());

        assertThat(response.foods()).hasSize(12);
        // detectedCount reste le nombre reellement vu sur la photo.
        assertThat(response.detectedCount()).isEqualTo(20);
    }

    @Test
    @DisplayName("Un type MIME absent ne bloque pas l'analyse")
    void missingContentTypeFallsBackToJpeg() {
        MockMultipartFile noType =
                new MockMultipartFile("file", "repas.jpg", null, new byte[]{1, 2, 3});
        when(gemini.detectFoods(any(), anyString())).thenReturn(List.of());

        assertThat(service.analyze(noType).foods()).isEmpty();
        verify(gemini).detectFoods(any(), org.mockito.ArgumentMatchers.eq("image/jpeg"));
    }
}
