package com.fitforge.api.nutrition.voice.client;

import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.nutrition.ai.client.GeminiDtos;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import com.fitforge.api.admin.service.AiCallRecorder;
import com.fitforge.api.common.enums.AiFeature;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import tools.jackson.databind.ObjectMapper;

import java.time.Duration;
import java.util.Base64;
import java.util.List;
import java.util.Map;

/**
 * Client <b>Gemini</b> pour l'ajout de repas <b>a la voix</b>.
 *
 * <p>L'adherent appuie sur un bouton et dit ce qu'il a mange :
 * « ce midi j'ai pris deux oeufs, une tranche de pain complet et un yaourt
 * nature ». Le modele fait <b>les deux choses a la fois</b> — il transcrit et
 * il extrait les aliments avec leurs quantites — en un seul appel.
 *
 * <h2>Pourquoi envoyer l'audio directement plutot que de le transcrire d'abord ?</h2>
 * <p>Une chaine « reconnaissance vocale puis analyse du texte » perd le
 * contexte : un moteur de transcription generaliste ecrit « du bled » pour
 * « du blé », « deux zeus » pour « deux oeufs ». En donnant l'audio au meme
 * modele qui doit comprendre un repas, on lui laisse lever ces ambiguites
 * <i>avec</i> la connaissance du domaine. Un aller-retour reseau en moins,
 * aussi.
 *
 * <h2>Le repli texte</h2>
 * <p>{@link #detectFromText(String)} refait le meme travail a partir d'une
 * phrase ecrite. Il sert dans deux cas : l'audio a ete refuse (format non
 * supporte, enregistrement inaudible), ou l'adherent corrige la transcription
 * affichee avant de relancer l'analyse. Meme consigne, meme schema de sortie,
 * donc exactement le meme resultat en aval.
 *
 * <p><b>Securite de la cle.</b> Identique au client de vision : en-tete
 * {@code x-goog-api-key}, jamais dans une URL, jamais journalisee, jamais
 * renvoyee au client. Aucune valeur par defaut dans le depot.
 *
 * <p><b>Sortie structuree.</b> {@code responseMimeType: application/json} et un
 * {@code responseSchema} imposent un objet conforme : pas de prose a nettoyer.
 */
@Component
@Slf4j
public class GeminiAudioClient {

    /** Nombre total de tentatives sur erreur reseau transitoire. */
    private static final int MAX_ATTEMPTS = 2;
    /** Pause entre deux tentatives. */
    private static final long RETRY_DELAY_MS = 500L;

    /**
     * Consigne donnee au modele.
     *
     * <p>Les memes exigences que pour la photo — noms <b>francais et
     * generiques</b>, quantites <b>en grammes</b> — plus trois specifiques a
     * l'oral :
     * <ul>
     *   <li><b>Convertir les unites parlees en grammes.</b> Personne ne dit
     *       « 125 grammes de yaourt » : on dit « un yaourt », « une tranche »,
     *       « un bol ». Le modele doit faire cette conversion, c'est tout
     *       l'interet de la fonctionnalite.</li>
     *   <li><b>Multiplier par la quantite enoncee.</b> « deux oeufs » vaut
     *       ~100 g, pas 50.</li>
     *   <li><b>Restituer la transcription.</b> C'est le seul moyen pour
     *       l'adherent de reperer un mot mal entendu.</li>
     * </ul>
     */
    private static final String PROMPT = """
            Tu es un nutritionniste. On te decrit un repas, a l'oral ou par ecrit.

            Extrais chaque aliment mentionne et sa quantite en grammes.

            Regles :
            - transcript : retranscris fidelement ce qui a ete dit (ou recopie le
              texte recu). Ne le reformule pas, ne le corrige pas.
            - Donne le nom de l'aliment en FRANCAIS, courant et GENERIQUE
              (exemples : « riz blanc », « blanc de poulet », « yaourt nature »,
              « pain complet »). Pas de nom de recette.
            - Convertis en GRAMMES les unites parlees, avec les equivalences
              usuelles : un oeuf ~50 g, une tranche de pain ~30 g, un yaourt
              ~125 g, une pomme ~150 g, un bol de riz cuit ~200 g, une cuillere
              a soupe d'huile ~10 g, un verre de lait ~200 g.
            - Multiplie par le nombre enonce : « deux oeufs » = 100 g.
            - Si aucune quantite n'est donnee, estime une portion normale pour
              un adulte.
            - Ignore tout ce qui n'est pas un aliment ou une boisson calorique.
            - Si rien de comestible n'est mentionne, renvoie une liste vide.
            - confidence : entre 0 et 1, ta certitude sur l'identification et la
              quantite. Baisse-la quand tu as devine la portion.
            """;

    /** Schema impose a la reponse du modele. */
    private static final Map<String, Object> RESPONSE_SCHEMA = Map.of(
            "type", "OBJECT",
            "properties", Map.of(
                    "transcript", Map.of("type", "STRING"),
                    "foods", Map.of(
                            "type", "ARRAY",
                            "items", Map.of(
                                    "type", "OBJECT",
                                    "properties", Map.of(
                                            "name", Map.of("type", "STRING"),
                                            "grams", Map.of("type", "NUMBER"),
                                            "confidence", Map.of("type", "NUMBER")
                                    ),
                                    "required", List.of("name", "grams")
                            )
                    )
            ),
            "required", List.of("transcript", "foods")
    );

    private final RestClient restClient;
    private final AiCallRecorder recorder;
    private final ObjectMapper objectMapper;
    private final String model;
    private final boolean configured;

    public GeminiAudioClient(
            @Value("${gemini.api.key:}") String apiKey,
            @Value("${gemini.api.base-url}") String baseUrl,
            @Value("${gemini.api.model}") String model,
            @Value("${gemini.api.voice-timeout-seconds:30}") int timeoutSeconds,
            ObjectMapper objectMapper,
            AiCallRecorder recorder) {

        this.recorder = recorder;
        this.model = model;
        this.objectMapper = objectMapper;
        this.configured = apiKey != null && !apiKey.isBlank();

        this.restClient = RestClient.builder()
                .baseUrl(baseUrl)
                // En-tete officiel de Google : la cle reste hors des URLs.
                .defaultHeader("x-goog-api-key", configured ? apiKey : "unset")
                .requestFactory(requestFactory(Duration.ofSeconds(timeoutSeconds)))
                .build();

        if (configured) {
            log.info("Client Gemini vocal initialise (modele={}, timeout={}s)",
                    model, timeoutSeconds);
        } else {
            log.warn("GEMINI_API_KEY absente : l'ajout vocal de repas est desactive. "
                    + "Le reste du module nutrition fonctionne normalement.");
        }
    }

    private static ClientHttpRequestFactory requestFactory(Duration timeout) {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout((int) timeout.toMillis());
        factory.setReadTimeout((int) timeout.toMillis());
        return factory;
    }

    /** Vrai si une cle est configuree — sinon la fonctionnalite est hors service. */
    public boolean isConfigured() {
        return configured;
    }

    /**
     * Transcrit un enregistrement et en extrait les aliments.
     *
     * @param audioBytes contenu binaire de l'enregistrement
     * @param mimeType   type MIME reel ({@code audio/mp4}, {@code audio/mpeg}...)
     * @return la transcription et les aliments compris
     */
    public GeminiDtos.SpokenMealPayload detectFromAudio(byte[] audioBytes, String mimeType) {
        requireConfigured();

        return send(AiFeature.MEAL_VOICE, List.of(
                GeminiDtos.Part.ofText(PROMPT),
                GeminiDtos.Part.ofAudio(mimeType,
                        Base64.getEncoder().encodeToString(audioBytes))));
    }

    /**
     * Extrait les aliments d'une phrase ecrite.
     *
     * <p>Repli de {@link #detectFromAudio}, et chemin de correction : l'adherent
     * modifie la transcription affichee puis relance l'analyse.
     */
    public GeminiDtos.SpokenMealPayload detectFromText(String text) {
        requireConfigured();

        return send(AiFeature.MEAL_TEXT, List.of(
                GeminiDtos.Part.ofText(PROMPT),
                GeminiDtos.Part.ofText("Voici la description du repas :\n" + text)));
    }

    private void requireConfigured() {
        if (!configured) {
            throw new BusinessException(
                    "L'ajout vocal n'est pas configure sur ce serveur.");
        }
    }

    // ─────────────────────────────────────────────────────────────────

    /**
     * Envoi commun aux deux entrees. La fonction appelante est passee en
     * parametre pour que la supervision distingue le vocal de l'ecrit : ils
     * partagent ce code mais n'ont ni la meme latence (transcrire avant de
     * raisonner coute plus cher) ni les memes causes d'echec.
     */
    private GeminiDtos.SpokenMealPayload send(AiFeature feature, List<GeminiDtos.Part> parts) {
        GeminiDtos.Request request = new GeminiDtos.Request(
                List.of(new GeminiDtos.Content(parts)),
                new GeminiDtos.GenerationConfig("application/json", RESPONSE_SCHEMA, 0.2));

        GeminiDtos.Response response = recorder.measure(feature,
                () -> execute(() -> restClient.post()
                .uri("/models/{model}:generateContent", model)
                .contentType(MediaType.APPLICATION_JSON)
                .body(request)
                .retrieve()
                .body(GeminiDtos.Response.class)));

        return parse(response);
    }

    /** Extrait transcription + aliments du JSON produit par le modele. */
    private GeminiDtos.SpokenMealPayload parse(GeminiDtos.Response response) {
        if (response == null) {
            return empty();
        }

        String blockReason = response.blockReason();
        if (blockReason != null) {
            log.warn("Gemini vocal : requete bloquee ({})", blockReason);
            throw new BusinessException(
                    "Cet enregistrement n'a pas pu etre analyse. Reessayez.");
        }

        String json = response.firstText();
        if (json == null || json.isBlank()) {
            return empty();
        }

        try {
            GeminiDtos.SpokenMealPayload payload =
                    objectMapper.readValue(json, GeminiDtos.SpokenMealPayload.class);
            if (payload == null) {
                return empty();
            }
            List<GeminiDtos.DetectedFood> foods = payload.foods() == null
                    ? List.of()
                    : payload.foods().stream()
                    .filter(java.util.Objects::nonNull)
                    .filter(GeminiDtos.DetectedFood::isUsable)
                    .toList();
            return new GeminiDtos.SpokenMealPayload(payload.transcript(), foods);

        } catch (Exception e) {
            // Le schema impose devrait l'empecher, mais un modele reste un
            // modele : on degrade en « rien compris » plutot que d'exposer une
            // erreur technique a l'adherent.
            log.warn("Gemini vocal : reponse illisible malgre le schema impose ({})",
                    e.getMessage());
            return empty();
        }
    }

    private GeminiDtos.SpokenMealPayload empty() {
        return new GeminiDtos.SpokenMealPayload(null, List.of());
    }

    /**
     * Execute l'appel avec retry sur erreur reseau transitoire et traduction
     * des codes HTTP en exceptions metier.
     *
     * <p>Aucun message de log ni d'exception ne contient la cle API ni le corps
     * de la reponse d'erreur.
     */
    private <T> T execute(java.util.function.Supplier<T> call) {
        ResourceAccessException lastNetworkError = null;

        for (int attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            try {
                return call.get();

            } catch (ResourceAccessException e) {
                lastNetworkError = e;
                log.warn("Gemini vocal : echec reseau (tentative {}/{})", attempt, MAX_ATTEMPTS);
                if (attempt < MAX_ATTEMPTS) {
                    sleep();
                }

            } catch (RestClientResponseException e) {
                throw translate(e);
            }
        }

        log.error("Gemini vocal : service injoignable apres {} tentatives", MAX_ATTEMPTS,
                lastNetworkError);
        throw new BusinessException(
                "L'analyse vocale est momentanement injoignable. Reessayez dans un instant.");
    }

    /** Traduit un code HTTP Gemini en message lisible par l'adherent. */
    private RuntimeException translate(RestClientResponseException e) {
        HttpStatus status = HttpStatus.resolve(e.getStatusCode().value());
        // On journalise le CODE uniquement : le corps d'erreur de Google peut
        // reprendre la cle fournie, on ne le logge donc jamais.
        log.error("Gemini vocal : reponse HTTP {}", e.getStatusCode().value());

        if (status == null) {
            return new BusinessException("L'analyse vocale a renvoye une reponse inattendue.");
        }
        return switch (status) {
            case TOO_MANY_REQUESTS -> new BusinessException(
                    "Quota d'analyse atteint pour le moment. Reessayez dans quelques minutes.");
            case UNAUTHORIZED, FORBIDDEN -> new BusinessException(
                    "L'analyse vocale a ete refusee (configuration serveur).");
            // Cas typique d'un format audio que le modele n'accepte pas : on
            // aiguille explicitement vers le repli texte, qui lui marchera.
            case BAD_REQUEST -> new BusinessException(
                    "Cet enregistrement n'a pas pu etre analyse. "
                            + "Decrivez votre repas par ecrit.");
            case NOT_FOUND -> new BusinessException(
                    "Le modele d'analyse configure est introuvable (configuration serveur).");
            case PAYLOAD_TOO_LARGE -> new BusinessException(
                    "Enregistrement trop long pour etre analyse.");
            default -> new BusinessException(
                    "L'analyse vocale est momentanement indisponible.");
        };
    }

    private void sleep() {
        try {
            Thread.sleep(RETRY_DELAY_MS);
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
        }
    }
}
