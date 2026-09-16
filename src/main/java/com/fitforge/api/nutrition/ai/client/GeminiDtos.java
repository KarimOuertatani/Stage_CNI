package com.fitforge.api.nutrition.ai.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;
import java.util.Map;

/**
 * Mapping des echanges avec l'API Gemini {@code generateContent}.
 *
 * <p>Volontairement minimal : on n'expose que ce dont le module nutrition a
 * besoin. Toutes les reponses ignorent les champs inconnus, le schema de l'API
 * evoluant sans preavis.
 *
 * <p><b>Partage entre les deux entrees d'analyse</b> — la photo de repas
 * ({@code nutrition/vision}) et la description vocale ({@code nutrition/voice}).
 * Le protocole Gemini est identique : seul change le contenu envoye (une image
 * ou un extrait audio) et la consigne qui l'accompagne.
 */
public final class GeminiDtos {

    private GeminiDtos() {
    }

    // ── Requete ───────────────────────────────────────────────────────

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record Request(
            List<Content> contents,
            @JsonProperty("generationConfig") GenerationConfig generationConfig
    ) {
    }

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record Content(List<Part> parts) {
    }

    /**
     * Un fragment de message : soit du texte, soit un media encode en base 64.
     * Les deux champs sont exclusifs — le champ nul n'est pas serialise.
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record Part(
            String text,
            @JsonProperty("inline_data") InlineData inlineData
    ) {
        public static Part ofText(String text) {
            return new Part(text, null);
        }

        public static Part ofImage(String mimeType, String base64Data) {
            return new Part(null, new InlineData(mimeType, base64Data));
        }

        /**
         * Extrait audio. Gemini l'accepte par le meme canal
         * {@code inline_data} qu'une image — seul le type MIME change
         * ({@code audio/mp4}, {@code audio/mpeg}, {@code audio/wav}...).
         */
        public static Part ofAudio(String mimeType, String base64Data) {
            return new Part(null, new InlineData(mimeType, base64Data));
        }
    }

    public record InlineData(
            @JsonProperty("mime_type") String mimeType,
            String data
    ) {
    }

    /**
     * Configuration de generation.
     *
     * <p>{@code responseMimeType} + {@code responseSchema} forcent une reponse
     * <b>JSON conforme</b> : sans cela le modele renvoie de la prose, parfois
     * entouree de balises Markdown, qu'il faudrait deviner et nettoyer.
     *
     * <p>Temperature basse : on veut une lecture factuelle de l'assiette (ou de
     * ce qui a ete dit), pas de la creativite.
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record GenerationConfig(
            @JsonProperty("responseMimeType") String responseMimeType,
            @JsonProperty("responseSchema") Map<String, Object> responseSchema,
            Double temperature
    ) {
    }

    // ── Reponse ───────────────────────────────────────────────────────

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Response(
            List<Candidate> candidates,
            @JsonProperty("promptFeedback") PromptFeedback promptFeedback
    ) {
        /**
         * Texte de la premiere reponse, ou {@code null} si le modele n'a rien
         * produit (filtre de securite, requete rejetee...).
         */
        public String firstText() {
            if (candidates == null || candidates.isEmpty()) {
                return null;
            }
            Content content = candidates.get(0).content();
            if (content == null || content.parts() == null) {
                return null;
            }
            return content.parts().stream()
                    .map(Part::text)
                    .filter(t -> t != null && !t.isBlank())
                    .findFirst()
                    .orElse(null);
        }

        /** Motif de blocage eventuel, a des fins de journalisation. */
        public String blockReason() {
            return promptFeedback != null ? promptFeedback.blockReason() : null;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Candidate(
            Content content,
            @JsonProperty("finishReason") String finishReason
    ) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record PromptFeedback(
            @JsonProperty("blockReason") String blockReason
    ) {
    }

    // ── Charge utile metier (le JSON demande au modele) ───────────────

    /** Liste d'aliments telle que le modele doit la renvoyer (analyse de photo). */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record DetectionPayload(List<DetectedFood> foods) {
    }

    /**
     * Reponse attendue d'une analyse <b>vocale ou textuelle</b>.
     *
     * @param transcript ce que le modele a compris, restitue tel quel. Affiche
     *                   a l'adherent : c'est le seul moyen pour lui de reperer
     *                   un mot mal entendu et de corriger avant d'enregistrer.
     * @param foods      les aliments extraits de cette phrase
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record SpokenMealPayload(String transcript, List<DetectedFood> foods) {
    }

    /**
     * Un aliment repere par le modele, sur une photo ou dans une phrase.
     *
     * @param name       nom courant <b>en francais</b> (« riz blanc », « blanc de poulet »)
     * @param grams      quantite estimee en grammes
     * @param confidence indice de confiance du modele, entre 0 et 1
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record DetectedFood(String name, Double grams, Double confidence) {

        /** Ecarte les lignes inexploitables (nom vide, quantite absurde). */
        public boolean isUsable() {
            return name != null
                    && !name.isBlank()
                    && grams != null
                    && grams > 0
                    && grams <= 5000;
        }
    }
}
