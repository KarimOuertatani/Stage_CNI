package com.fitforge.api.nutrition.vision.client;

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
import org.springframework.web.client.RestClient;
import com.fitforge.api.admin.service.AiCallRecorder;
import com.fitforge.api.common.enums.AiFeature;
import org.springframework.web.client.RestClientResponseException;
import tools.jackson.databind.ObjectMapper;

import java.time.Duration;
import java.util.Base64;
import java.util.List;
import java.util.Map;

/**
 * Client de l'API <b>Gemini</b> ({@code generativelanguage.googleapis.com})
 * pour la lecture d'une photo de repas.
 *
 * <p><b>Securite de la cle.</b> Elle est injectee depuis la configuration
 * ({@code gemini.api.key}, alimentee par la variable d'environnement
 * {@code GEMINI_API_KEY}) et transmise dans l'en-tete <b>{@code x-goog-api-key}</b>
 * plutot qu'en parametre d'URL. Consequence : elle n'apparait dans aucun log
 * d'acces, aucune trace d'exception, aucun message d'erreur. Elle ne quitte
 * jamais le backend — l'application Flutter appelle notre propre API.
 * <b>Aucune valeur par defaut n'existe dans le depot.</b>
 *
 * <p><b>Fonctionnalite optionnelle.</b> Sans cle configuree, le client se
 * declare indisponible ({@link #isConfigured()}) et l'endpoint d'analyse
 * repond un message clair. Le reste du module nutrition n'est pas affecte.
 *
 * <p><b>Sortie structuree.</b> La requete impose {@code responseMimeType:
 * application/json} et un {@code responseSchema} : le modele ne peut renvoyer
 * qu'un objet conforme. On evite ainsi d'avoir a nettoyer de la prose ou des
 * blocs Markdown, source classique de fragilite avec les modeles de langage.
 */
@Component
@Slf4j
public class GeminiVisionClient {

    /** Nombre total de tentatives sur erreur reseau transitoire. */
    private static final int MAX_ATTEMPTS = 2;
    /** Pause entre deux tentatives. */
    private static final long RETRY_DELAY_MS = 500L;

    /**
     * Consigne donnee au modele.
     *
     * <p>Trois exigences y sont essentielles : des noms <b>francais et
     * generiques</b> (ce sont eux qui seront cherches dans le catalogue), une
     * quantite <b>en grammes</b>, et l'exclusion de tout ce qui n'est pas
     * comestible — sans quoi le modele decrit volontiers l'assiette et les
     * couverts.
     */
    private static final String PROMPT = """
            Tu es un nutritionniste qui analyse une photo de repas.

            Identifie chaque aliment visible et estime sa quantite en grammes.

            Regles :
            - Donne le nom de l'aliment en FRANCAIS, courant et GENERIQUE
              (exemples : « riz blanc », « blanc de poulet », « brocoli »,
              « huile d'olive »). Pas de marque, pas de nom de recette.
            - Separe les composants d'un plat compose plutot que de le nommer
              globalement.
            - Estime la quantite en grammes de la portion visible.
            - Ignore les assiettes, couverts, verres vides, nappes et decors.
            - Si tu ne reconnais aucun aliment, renvoie une liste vide.
            - confidence : entre 0 et 1, ta certitude sur l'identification.
            """;

    /** Schema impose a la reponse du modele. */
    private static final Map<String, Object> RESPONSE_SCHEMA = Map.of(
            "type", "OBJECT",
            "properties", Map.of(
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
            "required", List.of("foods")
    );

    private final RestClient restClient;
    private final AiCallRecorder recorder;
    private final ObjectMapper objectMapper;
    private final String model;
    private final boolean configured;

    public GeminiVisionClient(
            @Value("${gemini.api.key:}") String apiKey,
            @Value("${gemini.api.base-url}") String baseUrl,
            @Value("${gemini.api.model}") String model,
            @Value("${gemini.api.timeout-seconds:20}") int timeoutSeconds,
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
            log.info("Client Gemini initialise (modele={}, timeout={}s)", model, timeoutSeconds);
        } else {
            log.warn("GEMINI_API_KEY absente : l'analyse de photo de repas est desactivee. "
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
     * Analyse une photo et renvoie les aliments detectes.
     *
     * <p>Contrat tolerant : une photo sans aliment reconnaissable renvoie une
     * <b>liste vide</b>, jamais une exception. Seules les pannes reelles
     * (quota, cle refusee, service injoignable) remontent.
     *
     * @param imageBytes contenu binaire de la photo
     * @param mimeType   type MIME reel de l'image ({@code image/jpeg}...)
     * @return les aliments exploitables, dans l'ordre renvoye par le modele
     */
    public List<GeminiDtos.DetectedFood> detectFoods(byte[] imageBytes, String mimeType) {
        if (!configured) {
            throw new BusinessException(
                    "L'analyse de photo n'est pas configuree sur ce serveur.");
        }

        GeminiDtos.Request request = new GeminiDtos.Request(
                List.of(new GeminiDtos.Content(List.of(
                        GeminiDtos.Part.ofText(PROMPT),
                        GeminiDtos.Part.ofImage(mimeType,
                                Base64.getEncoder().encodeToString(imageBytes))
                ))),
                new GeminiDtos.GenerationConfig("application/json", RESPONSE_SCHEMA, 0.2)
        );

        GeminiDtos.Response response = recorder.measure(AiFeature.MEAL_PHOTO,
                () -> execute(() -> restClient.post()
                .uri("/models/{model}:generateContent", model)
                .contentType(MediaType.APPLICATION_JSON)
                .body(request)
                .retrieve()
                .body(GeminiDtos.Response.class)));

        return parse(response);
    }

    // ─────────────────────────────────────────────────────────────────

    /** Extrait la liste d'aliments du JSON produit par le modele. */
    private List<GeminiDtos.DetectedFood> parse(GeminiDtos.Response response) {
        if (response == null) {
            return List.of();
        }

        String blockReason = response.blockReason();
        if (blockReason != null) {
            // Photo refusee par les filtres de securite du modele.
            log.warn("Gemini : requete bloquee ({})", blockReason);
            throw new BusinessException(
                    "Cette photo n'a pas pu etre analysee. Essayez une autre image.");
        }

        String json = response.firstText();
        if (json == null || json.isBlank()) {
            return List.of();
        }

        try {
            GeminiDtos.DetectionPayload payload =
                    objectMapper.readValue(json, GeminiDtos.DetectionPayload.class);
            if (payload == null || payload.foods() == null) {
                return List.of();
            }
            return payload.foods().stream()
                    .filter(java.util.Objects::nonNull)
                    .filter(GeminiDtos.DetectedFood::isUsable)
                    .toList();

        } catch (Exception e) {
            // Le schema impose devrait l'empecher, mais un modele reste un
            // modele : on degrade en « aucune detection » plutot que d'exposer
            // une erreur technique a l'adherent.
            log.warn("Gemini : reponse illisible malgre le schema impose ({})", e.getMessage());
            return List.of();
        }
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
                // Timeout / DNS / connexion refusee : transitoire -> on retente.
                lastNetworkError = e;
                log.warn("Gemini : echec reseau (tentative {}/{})", attempt, MAX_ATTEMPTS);
                if (attempt < MAX_ATTEMPTS) {
                    sleep();
                }

            } catch (RestClientResponseException e) {
                throw translate(e);
            }
        }

        log.error("Gemini : service injoignable apres {} tentatives", MAX_ATTEMPTS,
                lastNetworkError);
        throw new BusinessException(
                "L'analyse de photo est momentanement injoignable. Reessayez dans un instant.");
    }

    /** Traduit un code HTTP Gemini en message lisible par l'adherent. */
    private RuntimeException translate(RestClientResponseException e) {
        HttpStatus status = HttpStatus.resolve(e.getStatusCode().value());
        // On journalise le CODE uniquement : le corps d'erreur de Google peut
        // reprendre la cle fournie, on ne le logge donc jamais.
        log.error("Gemini : reponse HTTP {}", e.getStatusCode().value());

        if (status == null) {
            return new BusinessException("L'analyse de photo a renvoye une reponse inattendue.");
        }
        return switch (status) {
            case TOO_MANY_REQUESTS -> new BusinessException(
                    "Quota d'analyse atteint pour le moment. Reessayez dans quelques minutes.");
            case UNAUTHORIZED, FORBIDDEN -> new BusinessException(
                    "L'analyse de photo a ete refusee (configuration serveur).");
            case BAD_REQUEST -> new BusinessException(
                    "Cette image n'a pas pu etre analysee. Essayez une autre photo.");
            case NOT_FOUND -> new BusinessException(
                    "Le modele d'analyse configure est introuvable (configuration serveur).");
            case PAYLOAD_TOO_LARGE -> new BusinessException(
                    "Photo trop volumineuse pour etre analysee.");
            default -> new BusinessException(
                    "L'analyse de photo est momentanement indisponible.");
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
