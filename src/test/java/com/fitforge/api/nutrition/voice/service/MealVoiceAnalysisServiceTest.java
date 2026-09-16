package com.fitforge.api.nutrition.voice.service;

import com.fitforge.api.common.enums.FoodResultSource;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.nutrition.ai.client.GeminiDtos;
import com.fitforge.api.nutrition.ai.dto.AnalyzedFoodDto;
import com.fitforge.api.nutrition.ai.service.DetectedFoodResolver;
import com.fitforge.api.nutrition.dto.FoodSearchResultDto;
import com.fitforge.api.nutrition.service.FoodCatalogService;
import com.fitforge.api.nutrition.voice.client.GeminiAudioClient;
import com.fitforge.api.nutrition.voice.dto.VoiceAnalysisResponse;
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
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Tests de l'ajout de repas <b>a la voix</b>.
 *
 * <p>Deux exigences dominent ici, et ce sont elles qui sont testees :
 * <ol>
 *   <li><b>La transcription revient toujours</b>, y compris quand rien n'a ete
 *       compris — c'est le seul moyen pour l'adherent de voir <i>pourquoi</i>
 *       et de corriger.</li>
 *   <li><b>Le repli texte est strictement equivalent</b> a la voie audio :
 *       meme traitement, meme reponse. Sans cela, corriger une transcription
 *       donnerait un resultat different de l'analyse initiale.</li>
 * </ol>
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class MealVoiceAnalysisServiceTest {

    @Mock
    private GeminiAudioClient gemini;
    @Mock
    private FoodCatalogService foodCatalog;

    private MealVoiceAnalysisService service;

    @BeforeEach
    void setUp() {
        // Le resolveur est le VRAI composant : c'est lui qui porte le calcul au
        // prorata et le dedoublonnage, partages avec l'analyse de photo.
        service = new MealVoiceAnalysisService(gemini, new DetectedFoodResolver(foodCatalog));
        ReflectionTestUtils.setField(service, "maxAudioBytes", 10L * 1024 * 1024);
    }

    private MockMultipartFile audio() {
        return new MockMultipartFile("file", "repas.m4a", "audio/mp4", new byte[]{1, 2, 3});
    }

    private FoodSearchResultDto catalogHit(String name, double kcal, double protein) {
        return new FoodSearchResultDto(
                UUID.randomUUID(), 171077L, null, name, null, "SR Legacy",
                FoodResultSource.LOCAL, true,
                kcal, protein, 0.0, 9.5, null);
    }

    private GeminiDtos.SpokenMealPayload spoken(String transcript,
                                               GeminiDtos.DetectedFood... foods) {
        return new GeminiDtos.SpokenMealPayload(transcript, List.of(foods));
    }

    // ── Cas nominal ──────────────────────────────────────────────────

    @Test
    @DisplayName("« deux oeufs » devient 100 g, avec ses macros au prorata")
    void computesMacrosFromSpokenQuantities() {
        when(gemini.detectFromAudio(any(), anyString())).thenReturn(spoken(
                "Ce midi j'ai mange deux oeufs",
                new GeminiDtos.DetectedFood("oeuf", 100.0, 0.9)));
        when(foodCatalog.search("oeuf"))
                .thenReturn(List.of(catalogHit("Oeuf, entier, cru", 143.0, 12.6)));

        VoiceAnalysisResponse response = service.analyzeVoice(audio());

        AnalyzedFoodDto food = response.foods().get(0);
        assertThat(food.matched()).isTrue();
        // 143 kcal/100 g x 100 g = 143 kcal ; 12,6 g de proteines
        assertThat(food.calories()).isEqualTo(143);
        assertThat(food.proteinG()).isEqualTo(12.6);
        assertThat(response.totalCalories()).isEqualTo(143);
        assertThat(response.matchedCount()).isEqualTo(1);
    }

    @Test
    @DisplayName("La transcription est renvoyee telle quelle")
    void returnsTranscript() {
        when(gemini.detectFromAudio(any(), anyString())).thenReturn(spoken(
                "J'ai mange une pomme",
                new GeminiDtos.DetectedFood("pomme", 150.0, 0.95)));
        when(foodCatalog.search(anyString()))
                .thenReturn(List.of(catalogHit("Pomme, crue", 52.0, 0.3)));

        assertThat(service.analyzeVoice(audio()).transcript())
                .isEqualTo("J'ai mange une pomme");
    }

    @Test
    @DisplayName("Les valeurs pour 100 g sont renvoyees pour le recalcul cote app")
    void exposesPer100gValues() {
        when(gemini.detectFromAudio(any(), anyString())).thenReturn(spoken(
                "un bol de riz",
                new GeminiDtos.DetectedFood("riz blanc", 200.0, 0.7)));
        when(foodCatalog.search(anyString()))
                .thenReturn(List.of(catalogHit("Riz, blanc, cuit", 130.0, 2.7)));

        AnalyzedFoodDto food = service.analyzeVoice(audio()).foods().get(0);

        assertThat(food.caloriesPer100g()).isEqualTo(130.0);
        assertThat(food.calories()).isEqualTo(260);   // 130 x 2
    }

    // ── Rien compris ─────────────────────────────────────────────────

    @Test
    @DisplayName("Rien de comestible : liste vide, mais la transcription reste")
    void keepsTranscriptWhenNothingUnderstood() {
        when(gemini.detectFromAudio(any(), anyString()))
                .thenReturn(spoken("euh... je sais plus"));

        VoiceAnalysisResponse response = service.analyzeVoice(audio());

        assertThat(response.foods()).isEmpty();
        assertThat(response.totalCalories()).isZero();
        // Le point du test : sans la transcription, l'adherent ne saurait pas
        // ce que le serveur a entendu, ni quoi corriger.
        assertThat(response.transcript()).isEqualTo("euh... je sais plus");
        verify(foodCatalog, never()).search(anyString());
    }

    @Test
    @DisplayName("Une transcription vide devient null, pas une chaine blanche")
    void blankTranscriptBecomesNull() {
        when(gemini.detectFromAudio(any(), anyString())).thenReturn(spoken("   "));

        assertThat(service.analyzeVoice(audio()).transcript()).isNull();
    }

    // ── Aliment introuvable ──────────────────────────────────────────

    @Test
    @DisplayName("Un aliment cite mais introuvable est conserve, marque non resolu")
    void unmatchedFoodIsKeptButFlagged() {
        when(gemini.detectFromAudio(any(), anyString())).thenReturn(spoken(
                "j'ai mange des bricks tunisiennes",
                new GeminiDtos.DetectedFood("bricks tunisiennes", 90.0, 0.6)));
        when(foodCatalog.search(anyString())).thenReturn(List.of());

        VoiceAnalysisResponse response = service.analyzeVoice(audio());

        AnalyzedFoodDto food = response.foods().get(0);
        assertThat(food.matched()).isFalse();
        assertThat(food.calories()).isNull();
        assertThat(response.detectedCount()).isEqualTo(1);
        assertThat(response.matchedCount()).isZero();
        assertThat(response.totalCalories()).isZero();
    }

    // ── Repli texte ──────────────────────────────────────────────────

    @Test
    @DisplayName("Le repli texte donne exactement la meme reponse que la voix")
    void textFallbackBehavesLikeVoice() {
        when(gemini.detectFromText("deux oeufs et du pain")).thenReturn(spoken(
                "deux oeufs et du pain",
                new GeminiDtos.DetectedFood("oeuf", 100.0, 0.9)));
        when(foodCatalog.search(anyString()))
                .thenReturn(List.of(catalogHit("Oeuf, entier, cru", 143.0, 12.6)));

        VoiceAnalysisResponse response = service.analyzeText("deux oeufs et du pain");

        assertThat(response.foods()).hasSize(1);
        assertThat(response.totalCalories()).isEqualTo(143);
        assertThat(response.transcript()).isEqualTo("deux oeufs et du pain");
    }

    @Test
    @DisplayName("Une description vide est refusee avant tout appel externe")
    void blankTextIsRejected() {
        assertThatThrownBy(() -> service.analyzeText("   "))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Decrivez");

        verify(gemini, never()).detectFromText(anyString());
    }

    // ── Fichier invalide ─────────────────────────────────────────────

    @Test
    @DisplayName("Un enregistrement vide est refuse avant tout appel externe")
    void emptyRecordingIsRejected() {
        MockMultipartFile empty =
                new MockMultipartFile("file", "vide.m4a", "audio/mp4", new byte[0]);

        assertThatThrownBy(() -> service.analyzeVoice(empty))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Aucun enregistrement");

        verify(gemini, never()).detectFromAudio(any(), anyString());
    }

    @Test
    @DisplayName("Un fichier qui n'est pas de l'audio est refuse")
    void nonAudioIsRejected() {
        MockMultipartFile pdf = new MockMultipartFile(
                "file", "facture.pdf", "application/pdf", new byte[]{1, 2, 3});

        assertThatThrownBy(() -> service.analyzeVoice(pdf))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("audio");

        verify(gemini, never()).detectFromAudio(any(), anyString());
    }

    @Test
    @DisplayName("Un enregistrement trop long est refuse avant encodage")
    void oversizedRecordingIsRejected() {
        ReflectionTestUtils.setField(service, "maxAudioBytes", 10L);
        MockMultipartFile big = new MockMultipartFile(
                "file", "long.m4a", "audio/mp4", new byte[64]);

        assertThatThrownBy(() -> service.analyzeVoice(big))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("trop long");

        verify(gemini, never()).detectFromAudio(any(), anyString());
    }

    @Test
    @DisplayName("Les alias de type audio sont ramenes a la forme attendue par le modele")
    void audioTypeAliasesAreNormalized() {
        MockMultipartFile m4a =
                new MockMultipartFile("file", "repas.m4a", "audio/x-m4a", new byte[]{1, 2});
        when(gemini.detectFromAudio(any(), anyString())).thenReturn(spoken("rien"));

        service.analyzeVoice(m4a);

        verify(gemini).detectFromAudio(any(), eq("audio/mp4"));
    }

    @Test
    @DisplayName("Un type MIME absent ne bloque pas l'analyse")
    void missingContentTypeFallsBackToMp4() {
        MockMultipartFile noType =
                new MockMultipartFile("file", "repas.m4a", null, new byte[]{1, 2, 3});
        when(gemini.detectFromAudio(any(), anyString())).thenReturn(spoken("rien"));

        assertThat(service.analyzeVoice(noType).foods()).isEmpty();
        verify(gemini).detectFromAudio(any(), eq("audio/mp4"));
    }

    // ── Panne du service d'analyse ───────────────────────────────────

    @Test
    @DisplayName("Une panne Gemini remonte telle quelle, avec son message metier")
    void geminiFailurePropagates() {
        when(gemini.detectFromAudio(any(), anyString()))
                .thenThrow(new BusinessException(
                        "L'analyse vocale est momentanement injoignable. Reessayez dans un instant."));

        assertThatThrownBy(() -> service.analyzeVoice(audio()))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("injoignable");
    }

    // ── Robustesse du modele ─────────────────────────────────────────

    @Test
    @DisplayName("Un aliment cite deux fois n'est propose qu'une fois")
    void deduplicatesRepeatedFoods() {
        when(gemini.detectFromAudio(any(), anyString())).thenReturn(spoken(
                "du pain, et encore du pain",
                new GeminiDtos.DetectedFood("pain", 30.0, 0.8),
                new GeminiDtos.DetectedFood("Pain", 30.0, 0.7)));
        when(foodCatalog.search(anyString()))
                .thenReturn(List.of(catalogHit("Pain, blanc", 265.0, 9.0)));

        assertThat(service.analyzeVoice(audio()).foods()).hasSize(1);
    }

    @Test
    @DisplayName("Le nombre d'aliments traites est plafonne")
    void capsNumberOfFoods() {
        List<GeminiDtos.DetectedFood> many = new java.util.ArrayList<>();
        for (int i = 0; i < 20; i++) {
            many.add(new GeminiDtos.DetectedFood("aliment " + i, 50.0, 0.5));
        }
        when(gemini.detectFromAudio(any(), anyString()))
                .thenReturn(new GeminiDtos.SpokenMealPayload("un long monologue", many));
        when(foodCatalog.search(anyString())).thenReturn(List.of());

        VoiceAnalysisResponse response = service.analyzeVoice(audio());

        assertThat(response.foods()).hasSize(DetectedFoodResolver.MAX_FOODS);
        // detectedCount reste le nombre reellement cite.
        assertThat(response.detectedCount()).isEqualTo(20);
    }
}
