package com.fitforge.api.nutrition.vision.service;

import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.nutrition.ai.client.GeminiDtos;
import com.fitforge.api.nutrition.ai.dto.AnalyzedFoodDto;
import com.fitforge.api.nutrition.ai.service.DetectedFoodResolver;
import com.fitforge.api.nutrition.vision.client.GeminiVisionClient;
import com.fitforge.api.nutrition.vision.dto.PhotoAnalysisResponse;
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
 * Analyse d'une photo de repas : de l'image aux macros.
 *
 * <p><b>Chaine complete :</b>
 * <ol>
 *   <li>Gemini lit la photo et renvoie des aliments <b>nommes en francais</b>
 *       avec une quantite estimee ;</li>
 *   <li>{@link DetectedFoodResolver} cherche chacun au catalogue (cache local,
 *       USDA, Open Food Facts) et calcule les macros au prorata.</li>
 * </ol>
 *
 * <p>Ce service ne garde donc que ce qui est <b>propre a la photo</b> : la
 * validation du fichier image et l'appel au modele de vision. Tout ce qui suit
 * est commun avec l'analyse vocale.
 *
 * <p><b>Rien n'est persiste.</b> Le resultat est une proposition : l'adherent
 * corrige les quantites puis confirme aliment par aliment via
 * {@code POST /nutrition/from-food}, qui reste le seul chemin d'ecriture.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class MealPhotoAnalysisService {

    /** Types d'images acceptes. */
    private static final Set<String> ALLOWED_TYPES =
            Set.of("image/jpeg", "image/jpg", "image/png", "image/webp", "image/heic", "image/heif");

    private final GeminiVisionClient gemini;
    private final DetectedFoodResolver resolver;

    @Value("${gemini.api.max-image-bytes:8388608}")
    private long maxImageBytes;

    /**
     * Analyse la photo et propose les aliments avec leurs macros.
     *
     * @param photo image envoyee par l'adherent
     * @throws BusinessException fichier invalide, ou service d'analyse indisponible
     */
    public PhotoAnalysisResponse analyze(MultipartFile photo) {
        byte[] bytes = readAndValidate(photo);

        List<GeminiDtos.DetectedFood> detected =
                gemini.detectFoods(bytes, normalizedType(photo.getContentType()));

        if (detected.isEmpty()) {
            log.debug("Analyse photo : aucun aliment detecte");
            return PhotoAnalysisResponse.empty();
        }

        List<AnalyzedFoodDto> foods = resolver.resolveAll(detected);
        DetectedFoodResolver.Totals totals = resolver.total(foods);

        return new PhotoAnalysisResponse(
                foods,
                detected.size(),
                totals.matchedCount(),
                totals.calories(),
                totals.proteinG(),
                totals.carbsG(),
                totals.fatG(),
                totals.fiberG());
    }

    // ── Validation du fichier ────────────────────────────────────────

    /** Verifie que le fichier est une image exploitable et en lit le contenu. */
    private byte[] readAndValidate(MultipartFile photo) {
        if (photo == null || photo.isEmpty()) {
            throw new BusinessException("Aucune photo n'a ete envoyee");
        }
        if (photo.getSize() > maxImageBytes) {
            throw new BusinessException(
                    "Photo trop volumineuse (max " + (maxImageBytes / (1024 * 1024)) + " Mo)");
        }

        String type = normalizedType(photo.getContentType());
        if (!ALLOWED_TYPES.contains(type)) {
            throw new BusinessException("Le fichier envoye n'est pas une image reconnue");
        }

        try {
            return photo.getBytes();
        } catch (IOException e) {
            throw new BusinessException("Photo illisible");
        }
    }

    /**
     * Type MIME normalise, avec repli sur JPEG.
     *
     * <p>Certains clients envoient {@code application/octet-stream} ou un type
     * suffixe ({@code image/jpeg; charset=...}). L'extension du contenu prime
     * de toute facon cote modele.
     */
    private String normalizedType(String contentType) {
        if (contentType == null || contentType.isBlank()) {
            return "image/jpeg";
        }
        String type = contentType.split(";")[0].trim().toLowerCase(Locale.ROOT);
        return "image/jpg".equals(type) ? "image/jpeg" : type;
    }
}
