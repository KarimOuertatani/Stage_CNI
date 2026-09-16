package com.fitforge.api.nutrition.voice.service;

import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.nutrition.ai.client.GeminiDtos;
import com.fitforge.api.nutrition.ai.dto.AnalyzedFoodDto;
import com.fitforge.api.nutrition.ai.service.DetectedFoodResolver;
import com.fitforge.api.nutrition.voice.client.GeminiAudioClient;
import com.fitforge.api.nutrition.voice.dto.VoiceAnalysisResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * Ajout d'un repas <b>a la voix</b> : de la phrase parlee aux macros.
 *
 * <p><b>Le geste le plus court du module nutrition.</b> L'adherent appuie,
 * dit « ce midi j'ai mange deux oeufs et une tranche de pain complet »,
 * relache. Le reste est automatique.
 *
 * <p><b>Chaine complete :</b>
 * <ol>
 *   <li>Gemini transcrit l'enregistrement <b>et</b> en extrait les aliments
 *       avec leurs quantites converties en grammes ;</li>
 *   <li>{@link DetectedFoodResolver} — le meme etage que pour la photo —
 *       cherche chacun au catalogue et calcule les macros au prorata.</li>
 * </ol>
 *
 * <p><b>Rien n'est persiste.</b> Comme pour la photo, le resultat est une
 * proposition : l'adherent corrige puis confirme via
 * {@code POST /nutrition/from-food}, seul chemin d'ecriture du journal. Une
 * phrase mal entendue ne doit jamais s'imposer au journal de quelqu'un.
 *
 * <p><b>Deux entrees, un seul traitement.</b> {@link #analyzeText(String)}
 * refait le meme parcours a partir d'une phrase ecrite. C'est le repli quand
 * l'audio est refuse, et le chemin de correction quand la transcription
 * comporte un mot de travers.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class MealVoiceAnalysisService {

    /**
     * Types audio acceptes, <b>apres normalisation</b> (voir
     * {@link #normalizedType(String)} : les alias y sont deja ramenes a ces
     * formes canoniques).
     *
     * <p>L'app enregistre en <b>AAC dans un conteneur MP4</b>
     * ({@code audio/mp4}), comme les messages vocaux du chat — c'est le format
     * natif et le mieux compresse sur Android comme sur iOS. Les autres sont
     * acceptes pour ne pas dependre d'un detail de plateforme.
     */
    private static final Set<String> ALLOWED_TYPES = Set.of(
            "audio/mp4", "audio/mpeg", "audio/wav",
            "audio/ogg", "audio/opus", "audio/webm", "audio/flac");

    private final GeminiAudioClient gemini;
    private final DetectedFoodResolver resolver;

    @Value("${gemini.api.max-audio-bytes:10485760}")
    private long maxAudioBytes;

    /**
     * Analyse un enregistrement vocal et propose les aliments avec leurs macros.
     *
     * @param audio enregistrement envoye par l'adherent
     * @throws BusinessException fichier invalide, ou service d'analyse indisponible
     */
    public VoiceAnalysisResponse analyzeVoice(MultipartFile audio) {
        byte[] bytes = readAndValidate(audio);

        GeminiDtos.SpokenMealPayload payload =
                gemini.detectFromAudio(bytes, normalizedType(audio.getContentType()));

        return summarize(payload);
    }

    /**
     * Analyse une description ecrite du repas.
     *
     * <p>Meme consigne et meme schema que la voie audio : le resultat est
     * strictement de meme nature, donc traite par le meme code en aval.
     */
    public VoiceAnalysisResponse analyzeText(String text) {
        String description = text == null ? "" : text.trim();
        if (description.isBlank()) {
            throw new BusinessException("Decrivez ce que vous avez mange");
        }

        return summarize(gemini.detectFromText(description));
    }

    // ── Assemblage de la reponse ─────────────────────────────────────

    private VoiceAnalysisResponse summarize(GeminiDtos.SpokenMealPayload payload) {
        String transcript = cleanTranscript(payload.transcript());

        if (payload.foods().isEmpty()) {
            // La transcription est conservee : elle explique a l'adherent
            // POURQUOI rien n'a ete compris, et il peut la corriger.
            log.debug("Analyse vocale : aucun aliment compris");
            return VoiceAnalysisResponse.empty(transcript);
        }

        List<AnalyzedFoodDto> foods = resolver.resolveAll(payload.foods());
        DetectedFoodResolver.Totals totals = resolver.total(foods);

        return new VoiceAnalysisResponse(
                transcript,
                foods,
                payload.foods().size(),
                totals.matchedCount(),
                totals.calories(),
                totals.proteinG(),
                totals.carbsG(),
                totals.fatG(),
                totals.fiberG());
    }

    /** Transcription vide -&gt; {@code null}, pour que l'app n'affiche pas un cadre creux. */
    private String cleanTranscript(String transcript) {
        if (transcript == null) {
            return null;
        }
        String trimmed = transcript.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    // ── Validation du fichier ────────────────────────────────────────

    /** Verifie que le fichier est un enregistrement exploitable et en lit le contenu. */
    private byte[] readAndValidate(MultipartFile audio) {
        if (audio == null || audio.isEmpty()) {
            throw new BusinessException("Aucun enregistrement n'a ete envoye");
        }
        if (audio.getSize() > maxAudioBytes) {
            throw new BusinessException(
                    "Enregistrement trop long (max " + (maxAudioBytes / (1024 * 1024)) + " Mo)");
        }

        String type = normalizedType(audio.getContentType());
        if (!ALLOWED_TYPES.contains(type)) {
            throw new BusinessException("Le fichier envoye n'est pas un enregistrement audio reconnu");
        }

        try {
            return audio.getBytes();
        } catch (IOException e) {
            throw new BusinessException("Enregistrement illisible");
        }
    }

    /**
     * Type MIME normalise, avec repli sur {@code audio/mp4}.
     *
     * <p>Le type arrive souvent suffixe ({@code audio/mp4; codecs=mp4a}) ou
     * sous un alias historique : {@code audio/m4a} et {@code audio/x-m4a}
     * designent le meme conteneur MP4, {@code audio/mp3} le meme flux que
     * {@code audio/mpeg}. On les ramene a la forme que Gemini attend.
     */
    private String normalizedType(String contentType) {
        if (contentType == null || contentType.isBlank()) {
            return "audio/mp4";
        }
        String type = contentType.split(";")[0].trim().toLowerCase(Locale.ROOT);
        return switch (type) {
            case "audio/m4a", "audio/x-m4a", "audio/aac" -> "audio/mp4";
            case "audio/mp3" -> "audio/mpeg";
            case "audio/x-wav" -> "audio/wav";
            default -> type;
        };
    }
}
