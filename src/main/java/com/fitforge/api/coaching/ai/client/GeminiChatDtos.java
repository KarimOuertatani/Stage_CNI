package com.fitforge.api.coaching.ai.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;
import java.util.Map;

/**
 * Mapping des echanges Gemini pour une <b>conversation</b>.
 *
 * <p><b>Pourquoi un fichier distinct de celui de la nutrition ?</b> Ce n'est pas
 * de la duplication : la forme de la requete differe reellement.
 *
 * <table border="1">
 *   <caption>Ce qui change</caption>
 *   <tr><th></th><th>Photo / vocal</th><th>Conversation</th></tr>
 *   <tr><td>Tours</td><td>un seul</td><td><b>plusieurs</b> — chaque
 *       {@code Content} porte un {@code role}</td></tr>
 *   <tr><td>Consigne</td><td>dans le contenu</td>
 *       <td><b>{@code systemInstruction}</b>, hors de la conversation</td></tr>
 *   <tr><td>Media</td><td>{@code inline_data}</td><td>texte uniquement</td></tr>
 * </table>
 *
 * <p>Le {@code systemInstruction} n'est pas un detail de confort : une consigne
 * placee dans un message ordinaire est <b>au meme niveau</b> que ce que
 * l'adherent ecrit, donc discutable par lui. Placee dans le champ systeme, elle
 * garde son rang.
 */
public final class GeminiChatDtos {

    private GeminiChatDtos() {
    }

    // ── Requete ───────────────────────────────────────────────────────

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record Request(
            @JsonProperty("systemInstruction") Content systemInstruction,
            List<Content> contents,
            @JsonProperty("generationConfig") GenerationConfig generationConfig
    ) {
    }

    /**
     * Un tour de conversation.
     *
     * @param role {@code "user"} ou {@code "model"} — les seules valeurs
     *             acceptees par l'API. {@code null} pour la consigne systeme,
     *             qui n'appartient a personne.
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record Content(String role, List<Part> parts) {

        public static Content system(String text) {
            return new Content(null, List.of(new Part(text)));
        }

        public static Content user(String text) {
            return new Content("user", List.of(new Part(text)));
        }

        /** Reponse precedente du coach. Cote API Gemini, le role est « model ». */
        public static Content model(String text) {
            return new Content("model", List.of(new Part(text)));
        }
    }

    public record Part(String text) {
    }

    /**
     * Configuration de generation.
     *
     * <p>{@code responseSchema} force une reponse <b>JSON conforme</b> : ici ce
     * n'est pas seulement du confort de parsing, c'est ce qui permet au modele
     * de nous rendre son <b>classement de perimetre</b> en meme temps que sa
     * reponse, en un seul appel.
     *
     * <p>Temperature volontairement modeste : un coach doit etre constant. Trop
     * haute, il improviserait des conseils differents a la meme question.
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record GenerationConfig(
            @JsonProperty("responseMimeType") String responseMimeType,
            @JsonProperty("responseSchema") Map<String, Object> responseSchema,
            Double temperature,
            @JsonProperty("maxOutputTokens") Integer maxOutputTokens
    ) {
    }

    // ── Reponse ───────────────────────────────────────────────────────

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Response(
            List<Candidate> candidates,
            @JsonProperty("promptFeedback") PromptFeedback promptFeedback
    ) {
        /** Texte de la premiere reponse, ou {@code null} si le modele n'a rien produit. */
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

    // ── Charge utile metier ───────────────────────────────────────────

    /**
     * Ce que le modele doit renvoyer : <b>son classement, puis sa reponse</b>.
     *
     * <p>L'ordre des champs n'est pas indifferent. Un modele genere de gauche a
     * droite : en lui faisant ecrire {@code topic} <i>avant</i> {@code reply},
     * on l'oblige a decider du perimetre <b>avant</b> de rediger. S'il redigeait
     * d'abord, il se contenterait de justifier ce qu'il vient d'ecrire.
     *
     * @param topic sujet retenu, dont {@code HORS_SUJET}
     * @param reply reponse de coach — ignoree si le sujet est hors perimetre,
     *              l'application ayant alors son propre texte de refus
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record CoachAnswer(String topic, String reply) {

        public boolean isUsable() {
            return reply != null && !reply.isBlank();
        }
    }
}
