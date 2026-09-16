package com.fitforge.api.admin.service;

import com.fitforge.api.common.enums.AiFeature;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.time.Duration;
import java.util.List;
import java.util.Map;

/**
 * Sonde de disponibilite de Gemini, declenchee depuis la console.
 *
 * <h2>Pourquoi une sonde, alors que le journal d'appels existe deja</h2>
 * Le journal dit ce qui s'est passe ; il ne dit rien quand il ne s'est rien
 * passe. Un dimanche matin sans aucun appel, la page afficherait « 0 echec »
 * pour un service totalement hors ligne. La sonde repond a la seule question a
 * laquelle l'historique ne peut pas repondre : <b>est-ce que ca marche
 * maintenant ?</b>
 *
 * <h2>Pourquoi elle ne reutilise aucun des quatre clients</h2>
 * Passer par {@code GeminiCoachClient} aurait ete plus court, mais aurait
 * fausse ce qu'on mesure : la reponse du coach traverse une consigne systeme,
 * un schema JSON impose et douze messages d'historique. Un echec n'aurait plus
 * distingue « Gemini est injoignable » de « notre schema est invalide ».
 *
 * <p>La sonde envoie donc la plus petite requete possible -- un mot, une seule
 * unite de sortie -- et ne teste qu'une chose : la cle est-elle acceptee et le
 * service repond-il. C'est aussi ce qui la rend gratuite en pratique, alors
 * qu'elle partage le quota des fonctions reelles.
 */
@Component
@Slf4j
public class GeminiProbeClient {

    private final RestClient restClient;
    private final String model;
    private final boolean configured;
    private final AiCallRecorder recorder;

    public GeminiProbeClient(
            @Value("${gemini.api.key:}") String apiKey,
            @Value("${gemini.api.base-url}") String baseUrl,
            @Value("${gemini.api.model}") String model,
            AiCallRecorder recorder) {

        this.model = model;
        this.recorder = recorder;
        this.configured = apiKey != null && !apiKey.isBlank();

        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        // Delai court : une sonde qui met 90 secondes a repondre « indisponible »
        // n'est pas une sonde, c'est une page qui a l'air plantee.
        Duration timeout = Duration.ofSeconds(10);
        factory.setConnectTimeout((int) timeout.toMillis());
        factory.setReadTimeout((int) timeout.toMillis());

        this.restClient = RestClient.builder()
                .baseUrl(baseUrl)
                // En-tete officiel de Google : la cle reste hors des URLs.
                .defaultHeader("x-goog-api-key", configured ? apiKey : "unset")
                .requestFactory((ClientHttpRequestFactory) factory)
                .build();
    }

    public boolean isConfigured() {
        return configured;
    }

    /**
     * Resultat d'une sonde.
     *
     * @param reachable vrai si le modele a repondu
     * @param latencyMs duree de l'aller-retour
     * @param error     nature de l'echec (code HTTP ou classe), jamais le corps
     *                  de la reponse -- Google y reprend parfois la cle fournie
     */
    public record ProbeResult(boolean reachable, long latencyMs, String error) {}

    /**
     * Appelle le modele avec la plus petite requete possible.
     *
     * <p>L'echec est <b>capture</b> et transforme en resultat, contrairement au
     * reste du projet ou une panne de Gemini remonte en exception. La difference
     * est de nature : ici, « le service est en panne » n'est pas une erreur de
     * l'appel, c'en est la reponse. Renvoyer une 500 a la console lui ferait
     * afficher un bandeau d'erreur au lieu de l'information demandee.
     */
    public ProbeResult probe() {
        if (!configured) {
            return new ProbeResult(false, 0, "GEMINI_API_KEY absente");
        }

        Map<String, Object> request = Map.of(
                "contents", List.of(Map.of("parts", List.of(Map.of("text", "ping")))),
                "generationConfig", Map.of("maxOutputTokens", 1));

        long start = System.nanoTime();
        try {
            recorder.measure(AiFeature.HEALTH_PROBE, () -> restClient.post()
                    .uri("/models/{model}:generateContent", model)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(request)
                    .retrieve()
                    .body(String.class));

            return new ProbeResult(true, elapsedMs(start), null);

        } catch (RuntimeException e) {
            // Le CODE seul, jamais le corps : meme regle que les clients.
            log.warn("Sonde Gemini en echec : {}", e.getClass().getSimpleName());
            return new ProbeResult(false, elapsedMs(start), shortError(e));
        }
    }

    private static String shortError(RuntimeException e) {
        if (e instanceof org.springframework.web.client.RestClientResponseException http) {
            return "HTTP " + http.getStatusCode().value();
        }
        return e.getClass().getSimpleName();
    }

    private static long elapsedMs(long startNanos) {
        return (System.nanoTime() - startNanos) / 1_000_000L;
    }
}
