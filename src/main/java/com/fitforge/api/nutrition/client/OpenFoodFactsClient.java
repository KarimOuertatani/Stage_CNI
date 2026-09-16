package com.fitforge.api.nutrition.client;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

import java.time.Duration;
import java.util.List;
import java.util.Optional;

/**
 * Client de l'API <b>Open Food Facts</b> ({@code world.openfoodfacts.org}).
 *
 * <p><b>Pourquoi cette seconde source ?</b> USDA FoodData Central couvre
 * remarquablement les aliments <i>generiques</i> (banane crue, blanc de poulet,
 * riz cuit) mais tres mal les <b>produits emballes et les marques</b> vendus en
 * Europe : yaourts, barres cerealieres, plats prepares, biscuits. C'est
 * exactement ce que l'adherent mange le plus souvent et ce qui echouait le plus
 * a l'ajout. Open Food Facts est une base collaborative de plusieurs millions
 * de produits du commerce, indexes par code-barres.
 *
 * <p><b>Aucune cle API.</b> L'API est publique et gratuite. Elle exige en
 * revanche un en-tete {@code User-Agent} identifiant l'application : une
 * requete anonyme peut etre refusee ou limitee. C'est la seule « autorisation »
 * a fournir, et elle n'a rien d'un secret.
 *
 * <p><b>Licence.</b> Les donnees Open Food Facts sont publiees sous
 * <b>ODbL</b> : leur reutilisation impose de crediter la source. La mention
 * « Open Food Facts (ODbL) » figure dans les mentions legales de
 * l'application.
 *
 * <p><b>Complementaire, jamais prioritaire.</b> Ce client n'est interroge que
 * lorsque le cache local <i>et</i> USDA n'ont rien donne : les donnees OFF sont
 * contributives, donc de qualite plus heterogene que celles de l'USDA.
 *
 * <p><b>Contrat tolerant.</b> Toutes les methodes degradent en « aucun
 * resultat » plutot que de lever une exception : Open Food Facts est une
 * source d'<i>appoint</i>, sa panne ne doit jamais casser une recherche
 * d'aliment qui aurait pu aboutir autrement.
 */
@Component
@Slf4j
public class OpenFoodFactsClient {

    /**
     * Timeout volontairement court.
     *
     * <p>OFF n'est interroge qu'en <b>dernier recours</b>, apres un aller-retour
     * USDA infructueux : l'adherent attend deja depuis quelques secondes. Mieux
     * vaut abandonner vite que de rallonger indefiniment une recherche.
     */
    private static final Duration TIMEOUT = Duration.ofSeconds(6);

    /** Nombre de resultats demandes par recherche. */
    private static final int PAGE_SIZE = 10;

    /**
     * Champs demandes explicitement.
     *
     * <p>Une fiche OFF complete pese plusieurs dizaines de kilo-octets (photos,
     * additifs, empreinte carbone, historique des contributions...). En
     * restreignant les champs, la reponse tombe a quelques centaines d'octets
     * par produit — un gain de latence tres net sur un reseau mobile.
     */
    private static final String FIELDS =
            "code,product_name,product_name_fr,brands,nutriments";

    private final RestClient restClient;
    private final boolean enabled;

    public OpenFoodFactsClient(
            @Value("${openfoodfacts.api.base-url:https://world.openfoodfacts.org}") String baseUrl,
            @Value("${openfoodfacts.api.user-agent:FitForge-AI/1.0}") String userAgent,
            @Value("${openfoodfacts.api.enabled:true}") boolean enabled) {

        this.enabled = enabled;
        this.restClient = RestClient.builder()
                .baseUrl(baseUrl)
                // Exige par Open Food Facts : une requete sans User-Agent
                // identifiable peut etre rejetee ou fortement limitee.
                .defaultHeader("User-Agent", userAgent)
                .defaultHeader("Accept", "application/json")
                .requestFactory(requestFactory())
                .build();

        if (enabled) {
            log.info("Client Open Food Facts initialise (base={}, user-agent={})",
                    baseUrl, userAgent);
        } else {
            log.warn("Open Food Facts desactive : les produits de marque ne seront "
                    + "cherches que dans USDA et le catalogue local.");
        }
    }

    private static org.springframework.http.client.ClientHttpRequestFactory requestFactory() {
        var factory = new org.springframework.http.client.SimpleClientHttpRequestFactory();
        factory.setConnectTimeout((int) TIMEOUT.toMillis());
        factory.setReadTimeout((int) TIMEOUT.toMillis());
        return factory;
    }

    /** Vrai si la source d'appoint est active (desactivable par configuration). */
    public boolean isEnabled() {
        return enabled;
    }

    /**
     * Recherche de produits par mot-cle.
     *
     * <p>La requete est envoyee <b>telle que l'adherent l'a saisie</b>, en
     * francais : contrairement a USDA, OFF est multilingue et indexe les
     * libelles francais des produits vendus en France. Y envoyer la traduction
     * anglaise du lexique culinaire donnerait de moins bons resultats.
     *
     * @param query terme de recherche
     * @return les produits exploitables, <b>liste vide</b> en cas de panne
     */
    public List<OpenFoodFactsDtos.Product> searchProducts(String query) {
        if (!enabled || query == null || query.isBlank()) {
            return List.of();
        }

        OpenFoodFactsDtos.SearchResponse response = execute(
                () -> restClient.get()
                        .uri(uriBuilder -> uriBuilder
                                .path("/cgi/search.pl")
                                .queryParam("search_terms", query)
                                .queryParam("search_simple", 1)
                                .queryParam("action", "process")
                                .queryParam("json", 1)
                                .queryParam("page_size", PAGE_SIZE)
                                .queryParam("fields", FIELDS)
                                .build())
                        .retrieve()
                        .body(OpenFoodFactsDtos.SearchResponse.class),
                "recherche de produits");

        if (response == null || response.products() == null) {
            return List.of();
        }
        return response.products().stream()
                .filter(java.util.Objects::nonNull)
                // Beaucoup de fiches OFF sont incompletes (photo seule, aucun
                // nutriment saisi) : elles n'ont rien a faire dans un journal.
                .filter(OpenFoodFactsDtos.Product::isUsable)
                .toList();
    }

    /**
     * Fiche complete d'un produit par son code-barres.
     *
     * <p>Appele au moment de l'<b>import en cache</b>, comme
     * {@code GET /food/{fdcId}} du cote USDA : on fige alors des valeurs lues
     * a la source plutot que celles, potentiellement tronquees, d'un resultat
     * de recherche.
     *
     * @return le produit, ou {@link Optional#empty()} si le code est inconnu
     *         ou le service injoignable
     */
    public Optional<OpenFoodFactsDtos.Product> findByCode(String code) {
        if (!enabled || code == null || code.isBlank()) {
            return Optional.empty();
        }

        OpenFoodFactsDtos.ProductResponse response = execute(
                () -> restClient.get()
                        .uri(uriBuilder -> uriBuilder
                                .path("/api/v2/product/{code}.json")
                                .queryParam("fields", FIELDS)
                                .build(code))
                        .retrieve()
                        .body(OpenFoodFactsDtos.ProductResponse.class),
                "detail d'un produit");

        if (response == null || !response.found() || !response.product().isUsable()) {
            return Optional.empty();
        }
        return Optional.of(response.product());
    }

    // ─────────────────────────────────────────────────────────────────

    /**
     * Execute un appel Open Food Facts <b>sans jamais propager d'exception</b>.
     *
     * <p>C'est le choix structurant de ce client. USDA, lui, remonte ses
     * erreurs : c'est la source principale, et l'adherent doit savoir que son
     * quota est atteint. OFF est une source de <i>repli</i> : si elle tombe,
     * l'utilisateur ne doit meme pas s'en apercevoir — la recherche rend
     * simplement ce que les autres sources ont trouve.
     *
     * <p>Aucun retry : on est deja sur le troisieme aller-retour reseau d'une
     * meme recherche, une seconde tentative couterait plus en latence qu'elle
     * ne rapporterait en resultats.
     */
    private <T> T execute(java.util.function.Supplier<T> call, String operation) {
        try {
            return call.get();

        } catch (ResourceAccessException e) {
            // Timeout / DNS / connexion refusee.
            log.warn("Open Food Facts - {} : service injoignable ({})",
                    operation, e.getMessage());
            return null;

        } catch (RestClientResponseException e) {
            log.warn("Open Food Facts - {} : reponse HTTP {}",
                    operation, e.getStatusCode().value());
            return null;

        } catch (RuntimeException e) {
            // Reponse illisible (OFF renvoie parfois du HTML sur surcharge).
            log.warn("Open Food Facts - {} : reponse inexploitable ({})",
                    operation, e.getMessage());
            return null;
        }
    }
}
