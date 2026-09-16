package com.fitforge.api.nutrition.client;

import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

import java.time.Duration;
import java.util.List;

/**
 * Client de l'API <b>USDA FoodData Central</b> (api.nal.usda.gov/fdc/v1).
 *
 * <p><b>Securite de la cle.</b> La cle est injectee depuis la configuration
 * ({@code usda.api.key}, surchargeable par la variable d'environnement
 * {@code USDA_API_KEY}) et transmise via l'en-tete <b>{@code X-Api-Key}</b>
 * plutot qu'en parametre d'URL. Consequence directe : la cle n'apparait
 * <b>jamais</b> dans une URL, donc jamais dans les logs d'acces, les traces
 * d'exception ou les messages d'erreur. Elle ne quitte jamais le backend :
 * l'app Flutter appelle notre propre API.
 *
 * <p><b>Robustesse.</b> Timeouts courts (5 s), 2 tentatives sur erreur reseau
 * transitoire, et traduction des codes HTTP USDA en exceptions metier du projet.
 *
 * <p><b>Convention USDA.</b> Toutes les valeurs nutritionnelles renvoyees sont
 * normalisees <b>pour 100 g</b>.
 */
@Component
@Slf4j
public class UsdaApiClient {

    /** Timeout de connexion et de lecture. */
    private static final Duration TIMEOUT = Duration.ofSeconds(5);
    /** Nombre total de tentatives sur erreur reseau transitoire. */
    private static final int MAX_ATTEMPTS = 2;
    /** Pause entre deux tentatives. */
    private static final long RETRY_DELAY_MS = 300L;

    private final RestClient restClient;
    private final int pageSize;
    private final List<String> dataTypes;

    public UsdaApiClient(
            @Value("${usda.api.base-url}") String baseUrl,
            @Value("${usda.api.key}") String apiKey,
            @Value("${usda.api.page-size:20}") int pageSize,
            @Value("${usda.api.data-types}") String dataTypes) {

        this.pageSize = pageSize;
        this.dataTypes = List.of(dataTypes.split("\\s*,\\s*"));
        this.restClient = RestClient.builder()
                .baseUrl(baseUrl)
                // En-tete officiellement supporte par api.data.gov : la cle
                // reste hors des URLs (donc hors des logs).
                .defaultHeader("X-Api-Key", apiKey)
                .requestFactory(requestFactory())
                .build();

        log.info("Client USDA FoodData Central initialise (base={}, dataTypes={})",
                baseUrl, this.dataTypes);
    }

    private static ClientHttpRequestFactory requestFactory() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout((int) TIMEOUT.toMillis());
        factory.setReadTimeout((int) TIMEOUT.toMillis());
        return factory;
    }

    /**
     * Recherche d'aliments par mot-cle.
     *
     * <p>Contrat volontairement tolerant : un terme sans resultat renvoie une
     * <b>liste vide</b>, jamais une exception (cf. cahier des charges). Seules
     * les erreurs reellement bloquantes (quota, cle invalide, indisponibilite)
     * remontent en exception.
     *
     * @param query terme de recherche (non vide)
     * @return les aliments trouves, au plus {@code usda.api.page-size}
     */
    public List<UsdaDtos.Food> searchFoods(String query) {
        UsdaDtos.SearchResponse response = execute(
                () -> restClient.get()
                        .uri(uriBuilder -> {
                            uriBuilder.path("/foods/search")
                                    .queryParam("query", query)
                                    .queryParam("pageSize", pageSize)
                                    // Ameliore nettement la precision : tous les
                                    // mots saisis doivent etre presents.
                                    .queryParam("requireAllWords", true);
                            // Parametre de type liste : un queryParam par valeur
                            // (evite tout probleme d'encodage des virgules et
                            // des espaces de "SR Legacy").
                            dataTypes.forEach(dt -> uriBuilder.queryParam("dataType", dt));
                            return uriBuilder.build();
                        })
                        .retrieve()
                        .body(UsdaDtos.SearchResponse.class),
                "recherche d'aliments");

        if (response == null || response.foods() == null) {
            return List.of();
        }
        return response.foods().stream()
                .filter(f -> f.fdcId() != null)
                .filter(f -> f.description() != null && !f.description().isBlank())
                .toList();
    }

    /**
     * Detail complet d'un aliment (tous ses nutriments).
     *
     * @param fdcId identifiant USDA FoodData Central
     * @throws ResourceNotFoundException si l'aliment n'existe pas cote USDA
     */
    public UsdaDtos.Food getFoodDetails(Long fdcId) {
        UsdaDtos.Food food = execute(
                () -> restClient.get()
                        .uri("/food/{fdcId}", fdcId)
                        .retrieve()
                        .body(UsdaDtos.Food.class),
                "detail d'un aliment");

        if (food == null || food.fdcId() == null) {
            throw new ResourceNotFoundException("Aliment USDA introuvable : " + fdcId);
        }
        return food;
    }

    // ─────────────────────────────────────────────────────────────────

    /**
     * Execute un appel USDA avec retry sur erreur reseau transitoire et
     * traduction des erreurs HTTP en exceptions metier du projet.
     *
     * <p>Aucun message de log ni d'exception ne contient l'URL complete ni
     * la cle API.
     */
    private <T> T execute(java.util.function.Supplier<T> call, String operation) {
        ResourceAccessException lastNetworkError = null;

        for (int attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            try {
                return call.get();

            } catch (ResourceAccessException e) {
                // Timeout / DNS / connexion refusee : transitoire -> on retente.
                lastNetworkError = e;
                log.warn("USDA - {} : echec reseau (tentative {}/{})",
                        operation, attempt, MAX_ATTEMPTS);
                if (attempt < MAX_ATTEMPTS) {
                    sleep();
                }

            } catch (RestClientResponseException e) {
                throw translate(e, operation);
            }
        }

        log.error("USDA - {} : indisponible apres {} tentatives", operation, MAX_ATTEMPTS,
                lastNetworkError);
        throw new BusinessException(
                "Le service nutritionnel est momentanement injoignable. Reessayez dans un instant.");
    }

    /** Traduit un code HTTP USDA en exception metier lisible par le client. */
    private RuntimeException translate(RestClientResponseException e, String operation) {
        HttpStatus status = HttpStatus.resolve(e.getStatusCode().value());
        // On journalise le CODE uniquement : le corps d'erreur d'api.data.gov
        // peut contenir la cle fournie, on ne le logge donc jamais.
        log.error("USDA - {} : reponse HTTP {}", operation, e.getStatusCode().value());

        if (status == null) {
            return new BusinessException("Le service nutritionnel a renvoye une reponse inattendue.");
        }
        return switch (status) {
            case TOO_MANY_REQUESTS -> new BusinessException(
                    "Quota de recherche atteint pour le moment. Reessayez dans quelques minutes.");
            case FORBIDDEN, UNAUTHORIZED -> new BusinessException(
                    "Le service nutritionnel a refuse la requete (configuration serveur).");
            case NOT_FOUND -> new ResourceNotFoundException("Aliment introuvable dans la base USDA");
            default -> new BusinessException(
                    "Le service nutritionnel est momentanement indisponible.");
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
