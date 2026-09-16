package com.fitforge.api.nutrition.service;

import com.fitforge.api.common.enums.FoodResultSource;
import com.fitforge.api.common.enums.FoodSource;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.nutrition.client.OpenFoodFactsClient;
import com.fitforge.api.nutrition.client.OpenFoodFactsDtos;
import com.fitforge.api.nutrition.client.UsdaApiClient;
import com.fitforge.api.nutrition.client.UsdaDtos;
import com.fitforge.api.nutrition.dto.FoodSearchResultDto;
import com.fitforge.api.nutrition.entity.FoodItem;
import com.fitforge.api.nutrition.i18n.FoodLexicon;
import com.fitforge.api.nutrition.repository.FoodItemRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

/**
 * Catalogue d'aliments : recherche multi-sources + <b>cache local permanent</b>.
 *
 * <h2>Trois sources, interrogees dans cet ordre</h2>
 * <ol>
 *   <li><b>Cache local</b> — instantane, aucun appel reseau. Ce que l'adherent
 *       (ou n'importe quel autre) a deja ajoute une fois.</li>
 *   <li><b>USDA FoodData Central</b> — la reference pour les aliments
 *       <i>generiques</i> : banane crue, blanc de poulet, riz cuit.</li>
 *   <li><b>Open Food Facts</b> — <i>seulement si USDA n'a rien renvoye</i>.
 *       Comble le trou principal d'USDA : les <b>produits emballes et de
 *       marque</b> (yaourts, barres cerealieres, plats prepares), qui sont
 *       justement ceux qui echouaient le plus a l'ajout. Donnees sous licence
 *       ODbL, creditees dans les mentions legales.</li>
 * </ol>
 *
 * <p><b>Regle centrale :</b> on n'appelle JAMAIS une API externe pour un
 * aliment deja present en base ({@code usda_fdc_id} ou {@code off_code}
 * connu). Chaque aliment ajoute par un adherent enrichit definitivement le
 * catalogue pour tous les suivants.
 *
 * <p><b>Degradation gracieuse :</b> si USDA est injoignable ou son quota
 * atteint, la recherche se poursuit sur le catalogue local et Open Food Facts
 * plutot que d'echouer. L'erreur USDA n'est remontee que si <b>aucune</b>
 * source n'a rien a proposer.
 *
 * <p><b>Francisation.</b> USDA est une base anglophone : la saisie de
 * l'adherent est traduite en anglais <i>avant</i> l'appel, et chaque libelle
 * renvoye est traduit en francais <i>avant</i> l'affichage (voir
 * {@link FoodLexicon}). Open Food Facts, lui, est multilingue et porte
 * souvent un libelle francais : on l'interroge donc avec la saisie
 * <b>originale</b>, sans traduction.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FoodCatalogService {

    /** Longueur minimale d'un terme de recherche (evite les appels inutiles). */
    private static final int MIN_QUERY_LENGTH = 2;
    /** Nombre d'aliments recents proposes par defaut. */
    private static final int RECENT_LIMIT = 12;
    /** Plafond de resultats issus du repli local. */
    private static final int LOCAL_FALLBACK_LIMIT = 20;

    /**
     * Nombre d'aliments du cache local places en tete d'une recherche reussie.
     *
     * <p>Volontairement bas. Le cache local repond par sous-chaine : sur
     * « pomme », il remonterait volontiers vingt lignes contenant ce mot et
     * repousserait hors de vue les resultats classes par pertinence d'USDA.
     * Quelques entrees suffisent a offrir l'ajout instantane d'un aliment
     * habituel sans etouffer la recherche.
     */
    private static final int LOCAL_HEAD_LIMIT = 6;

    private final FoodItemRepository foodRepo;
    private final UsdaApiClient usda;
    private final OpenFoodFactsClient openFoodFacts;
    private final FoodLexicon lexicon;

    // ── Recherche ────────────────────────────────────────────────────

    /**
     * Recherche un aliment par mot-cle, <b>en francais</b>.
     *
     * <p>La saisie est traduite avant d'atteindre USDA (« blanc de poulet »
     * -&gt; « chicken breast ») : sans cela, une recherche francaise ne
     * renverrait jamais rien, la base USDA etant anglophone. Open Food Facts
     * recoit la saisie originale, sa base etant multilingue.
     *
     * <p>Contrat : un terme sans resultat renvoie une <b>liste vide</b>, jamais
     * une exception. Les resultats deja presents en catalogue sont marques
     * {@code source = LOCAL} et portent leur {@code foodItemId} : l'app peut
     * les ajouter sans le moindre appel externe.
     */
    @Transactional(readOnly = true)
    public List<FoodSearchResultDto> search(String query) {
        String term = query == null ? "" : query.trim();
        if (term.length() < MIN_QUERY_LENGTH) {
            return List.of();
        }
        String englishTerm = lexicon.toEnglishQuery(term);

        List<FoodSearchResultDto> results = new ArrayList<>();
        Set<Long> seenFdcIds = new HashSet<>();
        Set<String> seenOffCodes = new HashSet<>();

        // ── 1. Cache local ───────────────────────────────────────────
        // Zero latence, et ces aliments s'ajoutent sans aucun appel externe.
        // Une seule requete : la tete alimente les resultats tout de suite, la
        // queue est gardee de cote au cas ou les sources externes soient
        // muettes (voir l'etape 4).
        List<FoodItem> localItems = searchLocalItems(term, englishTerm, LOCAL_FALLBACK_LIMIT);
        int localHead = Math.min(localItems.size(), LOCAL_HEAD_LIMIT);
        for (FoodItem item : localItems.subList(0, localHead)) {
            results.add(toDto(item));
            remember(item, seenFdcIds, seenOffCodes);
        }

        // ── 2. USDA ──────────────────────────────────────────────────
        RuntimeException usdaError = null;
        List<UsdaDtos.Food> usdaFoods = List.of();
        try {
            usdaFoods = searchUsda(term, englishTerm);
        } catch (RuntimeException e) {
            // Quota atteint / service injoignable : on ne renonce pas, les
            // autres sources peuvent encore repondre. L'erreur n'est remontee
            // que si, au final, on n'a rien du tout a proposer.
            log.warn("Recherche USDA indisponible, poursuite sur les autres sources : {}",
                    e.getMessage());
            usdaError = e;
        }

        int fromUsda = 0;
        if (!usdaFoods.isEmpty()) {
            Map<Long, FoodItem> cached = cachedByFdcId(usdaFoods);
            for (UsdaDtos.Food food : usdaFoods) {
                if (!seenFdcIds.add(food.fdcId())) {
                    continue;           // deja remonte par le cache local
                }
                FoodItem known = cached.get(food.fdcId());
                if (known != null) {
                    results.add(toDto(known));      // valeurs de notre base
                    fromUsda++;
                } else if (food.hasUsableMacros()) {
                    results.add(toDto(food));       // valeurs USDA brutes
                    fromUsda++;
                }
                // Un aliment USDA sans aucune macro exploitable est ecarte :
                // il ne servirait a rien dans un journal alimentaire.
            }
        }

        // ── 3. Open Food Facts ───────────────────────────────────────
        // Uniquement si USDA n'a rien apporte. C'est le cas typique d'un
        // produit de marque : « Skyr Danone », « barre Grany », « Nutella ».
        if (fromUsda == 0) {
            results.addAll(searchOpenFoodFacts(term, seenOffCodes));
        }

        // ── 4. Le reste du cache local ───────────────────────────────
        // Les sources externes sont muettes (panne, quota, ou produit inconnu
        // des deux bases) : on deroule alors tout ce que le catalogue local
        // connait, plutot que de s'arreter aux six premiers.
        if (results.size() == localHead) {
            for (FoodItem item : localItems.subList(localHead, localItems.size())) {
                results.add(toDto(item));
            }
        }

        if (results.isEmpty() && usdaError != null) {
            throw usdaError;    // rien a proposer : on remonte l'erreur reelle
        }
        return results;
    }

    /**
     * Interroge USDA, avec repli sur le terme brut.
     *
     * <p>Un terme traduit qui ne donne rien est retente tel quel : cela couvre
     * les marques et les mots que le lexique aurait traduits a tort
     * (« Nature », « Sole »...).
     */
    private List<UsdaDtos.Food> searchUsda(String term, String englishTerm) {
        List<UsdaDtos.Food> foods = usda.searchFoods(englishTerm);
        if (foods.isEmpty() && !englishTerm.equalsIgnoreCase(term)) {
            foods = usda.searchFoods(term);
        }
        return foods;
    }

    /**
     * Interroge Open Food Facts avec la saisie <b>originale</b>.
     *
     * <p>Contrairement a USDA, OFF indexe les libelles francais des produits
     * vendus en France : lui envoyer la traduction anglaise du lexique
     * degraderait les resultats.
     *
     * <p>Les produits deja importes sont renvoyes depuis notre base (donc
     * {@code LOCAL}, ajoutables sans appel externe) plutot que re-proposes
     * comme nouveaux.
     */
    private List<FoodSearchResultDto> searchOpenFoodFacts(String term, Set<String> seenOffCodes) {
        List<OpenFoodFactsDtos.Product> products = openFoodFacts.searchProducts(term);
        if (products.isEmpty()) {
            return List.of();
        }

        Map<String, FoodItem> cached = cachedByOffCode(products);
        List<FoodSearchResultDto> results = new ArrayList<>(products.size());

        for (OpenFoodFactsDtos.Product product : products) {
            if (!seenOffCodes.add(product.code())) {
                continue;               // deja remonte par le cache local
            }
            FoodItem known = cached.get(product.code());
            results.add(known != null ? toDto(known) : toDto(product));
        }

        log.debug("Open Food Facts a complete la recherche « {} » : {} produit(s)",
                term, results.size());
        return results;
    }

    /**
     * Recherche restreinte au catalogue local (repli et aliments personnalises).
     *
     * <p>Interroge les deux langues : le libelle francais traduit et le libelle
     * d'origine.
     */
    @Transactional(readOnly = true)
    public List<FoodSearchResultDto> searchLocal(String term, String englishTerm) {
        return searchLocalItems(term, englishTerm, LOCAL_FALLBACK_LIMIT).stream()
                .map(this::toDto)
                .toList();
    }

    private List<FoodItem> searchLocalItems(String term, String englishTerm, int limit) {
        return foodRepo.searchByName(term, englishTerm, PageRequest.of(0, limit));
    }

    /** Aliments les plus utilises par l'adherent — re-ajout en deux gestes. */
    @Transactional(readOnly = true)
    public List<FoodSearchResultDto> recentForUser(UUID userId) {
        return foodRepo.findMostUsedByUser(userId, PageRequest.of(0, RECENT_LIMIT)).stream()
                .map(this::toDto)
                .toList();
    }

    // ── Resolution / import ──────────────────────────────────────────

    /**
     * Retrouve un aliment deja en catalogue par son id USDA, sans aucun appel
     * externe. Utilise par le rattrapage de collision (voir NutritionService).
     */
    @Transactional(readOnly = true)
    public Optional<FoodItem> findCachedByFdcId(Long fdcId) {
        return fdcId == null ? Optional.empty() : foodRepo.findByUsdaFdcId(fdcId);
    }

    /**
     * Retrouve un produit deja en catalogue par son code-barres Open Food
     * Facts, sans aucun appel externe.
     */
    @Transactional(readOnly = true)
    public Optional<FoodItem> findCachedByOffCode(String offCode) {
        return offCode == null || offCode.isBlank()
                ? Optional.empty()
                : foodRepo.findByOffCode(offCode);
    }

    /**
     * Resout un aliment vers une entite persistee, en important depuis la
     * source externe <b>seulement si necessaire</b>.
     *
     * <p>Ordre de resolution :
     * <ol>
     *   <li>{@code foodItemId} fourni -> lecture directe du catalogue ;</li>
     *   <li>{@code fdcId} deja en cache -> <b>aucun appel USDA</b>, sinon
     *       {@code GET /food/{fdcId}} puis mise en cache ;</li>
     *   <li>{@code offCode} deja en cache -> <b>aucun appel OFF</b>, sinon
     *       {@code GET /api/v2/product/{code}} puis mise en cache.</li>
     * </ol>
     *
     * <p><b>Pourquoi re-interroger la source plutot que faire confiance aux
     * valeurs deja affichees ?</b> Parce qu'elles transitent par le client :
     * les macros enregistrees dans le journal doivent venir du serveur, sinon
     * n'importe qui pourrait s'inventer un chocolat a 0 kcal.
     *
     * <p><b>{@code REQUIRES_NEW} volontaire :</b> l'import s'execute dans une
     * transaction independante de celle de l'appelant. En cas de collision sur
     * une contrainte d'unicite ({@code usda_fdc_id} ou {@code off_code}, deux
     * ajouts simultanes du meme aliment neuf), seule cette transaction-ci est
     * annulee : la transaction appelante reste saine et peut relire la ligne
     * validee par l'autre requete.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public FoodItem resolveOrImport(UUID foodItemId, Long fdcId, String offCode) {
        if (foodItemId != null) {
            return foodRepo.findById(foodItemId)
                    .orElseThrow(() -> new ResourceNotFoundException("Aliment introuvable"));
        }
        if (fdcId != null) {
            return resolveUsda(fdcId);
        }
        if (offCode != null && !offCode.isBlank()) {
            return resolveOpenFoodFacts(offCode.trim());
        }
        throw new BusinessException("Aucun aliment n'a ete designe");
    }

    /** Import USDA : cache d'abord, appel externe seulement en dernier recours. */
    private FoodItem resolveUsda(Long fdcId) {
        Optional<FoodItem> cached = foodRepo.findByUsdaFdcId(fdcId);
        if (cached.isPresent()) {
            return withFrenchName(cached.get());
        }

        UsdaDtos.Food detail = usda.getFoodDetails(fdcId);
        if (!detail.hasUsableMacros()) {
            throw new BusinessException(
                    "Cet aliment ne fournit pas de valeurs nutritionnelles exploitables");
        }

        FoodItem saved = foodRepo.saveAndFlush(toEntity(detail));
        log.info("Catalogue nutrition : aliment USDA {} importe en cache", fdcId);
        return saved;
    }

    /**
     * Import Open Food Facts : cache d'abord, appel externe ensuite.
     *
     * <p>La fiche complete est relue a la source au lieu de reprendre le
     * resultat de recherche : c'est le meme principe que le
     * {@code GET /food/{fdcId}} cote USDA, et cela garantit des valeurs
     * completes plutot que celles, parfois tronquees, d'un resultat de liste.
     */
    private FoodItem resolveOpenFoodFacts(String offCode) {
        Optional<FoodItem> cached = foodRepo.findByOffCode(offCode);
        if (cached.isPresent()) {
            return cached.get();
        }

        OpenFoodFactsDtos.Product product = openFoodFacts.findByCode(offCode)
                .orElseThrow(() -> new BusinessException(
                        "Ce produit n'est plus disponible dans la base Open Food Facts. "
                                + "Reessayez ou saisissez-le manuellement."));

        FoodItem saved = foodRepo.saveAndFlush(toEntity(product));
        log.info("Catalogue nutrition : produit Open Food Facts {} importe en cache", offCode);
        return saved;
    }

    // ── Libelles ─────────────────────────────────────────────────────

    /**
     * Libelle francais d'un aliment du catalogue.
     *
     * <p>Utilise la traduction figee a l'import quand elle existe, sinon
     * traduit a la volee : les aliments anterieurs a la francisation restent
     * ainsi lisibles avant meme d'avoir ete rattrapes en base.
     */
    public String frenchName(FoodItem item) {
        String stored = item.getNameFr();
        if (stored != null && !stored.isBlank()) {
            return stored;
        }
        return lexicon.toFrenchLabel(item.getName());
    }

    /**
     * Rattrapage silencieux des aliments importes avant la francisation (ou
     * avant un enrichissement du lexique) : on profite d'une transaction en
     * ecriture pour figer le libelle francais.
     */
    private FoodItem withFrenchName(FoodItem item) {
        if (item.getNameFr() == null || item.getNameFr().isBlank()) {
            item.setNameFr(lexicon.toFrenchLabel(item.getName()));
            foodRepo.save(item);
        }
        return item;
    }

    // ── Mapping ──────────────────────────────────────────────────────

    /** Memorise les identifiants d'un aliment local, pour ne pas le proposer deux fois. */
    private void remember(FoodItem item, Set<Long> fdcIds, Set<String> offCodes) {
        if (item.getUsdaFdcId() != null) {
            fdcIds.add(item.getUsdaFdcId());
        }
        if (item.getOffCode() != null) {
            offCodes.add(item.getOffCode());
        }
    }

    /** Les aliments USDA de la liste deja presents en catalogue, indexes par fdcId. */
    private Map<Long, FoodItem> cachedByFdcId(List<UsdaDtos.Food> foods) {
        List<Long> ids = foods.stream().map(UsdaDtos.Food::fdcId).toList();
        Map<Long, FoodItem> byId = new HashMap<>();
        for (FoodItem item : foodRepo.findByUsdaFdcIdIn(ids)) {
            byId.put(item.getUsdaFdcId(), item);
        }
        return byId;
    }

    /** Les produits OFF de la liste deja presents en catalogue, indexes par code-barres. */
    private Map<String, FoodItem> cachedByOffCode(List<OpenFoodFactsDtos.Product> products) {
        List<String> codes = products.stream().map(OpenFoodFactsDtos.Product::code).toList();
        Map<String, FoodItem> byCode = new HashMap<>();
        for (FoodItem item : foodRepo.findByOffCodeIn(codes)) {
            byCode.put(item.getOffCode(), item);
        }
        return byCode;
    }

    /** Entite USDA brute -> entite persistable (valeurs POUR 100 g). */
    private FoodItem toEntity(UsdaDtos.Food food) {
        String original = food.description().trim();
        return FoodItem.builder()
                .name(original)
                // Traduction figee une fois pour toutes a l'import : le
                // catalogue devient cherchable en francais.
                .nameFr(lexicon.toFrenchLabel(original))
                .brand(food.resolvedBrand())
                .usdaFdcId(food.fdcId())
                .dataType(food.dataType())
                .source(FoodSource.USDA)
                .caloriesPer100g(food.energyKcal())
                .proteinPer100g(food.nutrient(UsdaDtos.NUTRIENT_PROTEIN))
                .carbsPer100g(food.nutrient(UsdaDtos.NUTRIENT_CARBS))
                .fatPer100g(food.nutrient(UsdaDtos.NUTRIENT_FAT))
                .fiberPer100g(food.nutrient(UsdaDtos.NUTRIENT_FIBER))
                .build();
    }

    /**
     * Produit Open Food Facts -> entite persistable (valeurs POUR 100 g).
     *
     * <p>Le libelle n'est <b>pas</b> passe au lexique culinaire : OFF renvoie
     * deja un nom francais pour les produits vendus en France, et traduire
     * « Danette » ou « Petit Beurre » n'aurait aucun sens. Les deux colonnes
     * portent donc le meme libelle, ce qui garde la recherche locale
     * fonctionnelle dans les deux langues.
     */
    private FoodItem toEntity(OpenFoodFactsDtos.Product product) {
        String name = product.resolvedName();
        return FoodItem.builder()
                .name(name)
                .nameFr(name)
                .brand(product.firstBrand())
                .offCode(product.code())
                .source(FoodSource.OPEN_FOOD_FACTS)
                .caloriesPer100g(product.calories())
                .proteinPer100g(product.protein())
                .carbsPer100g(product.carbs())
                .fatPer100g(product.fat())
                .fiberPer100g(product.fiber())
                .build();
    }

    /** Aliment du catalogue -> resultat de recherche (libelle francais). */
    private FoodSearchResultDto toDto(FoodItem item) {
        return new FoodSearchResultDto(
                item.getId(),
                item.getUsdaFdcId(),
                item.getOffCode(),
                frenchName(item),
                item.getBrand(),
                item.getDataType(),
                // Peu importe d'ou il a ete importe : il est en cache, donc
                // ajoutable sans le moindre appel externe.
                FoodResultSource.LOCAL,
                true,
                item.getCaloriesPer100g(),
                item.getProteinPer100g(),
                item.getCarbsPer100g(),
                item.getFatPer100g(),
                item.getFiberPer100g());
    }

    /**
     * Aliment USDA non encore importe -> resultat de recherche.
     *
     * <p>Traduit a la volee : cet aliment n'est pas encore en base, sa
     * traduction sera figee s'il est effectivement ajoute a un repas.
     */
    private FoodSearchResultDto toDto(UsdaDtos.Food food) {
        return new FoodSearchResultDto(
                null,
                food.fdcId(),
                null,
                lexicon.toFrenchLabel(food.description().trim()),
                food.resolvedBrand(),
                food.dataType(),
                FoodResultSource.USDA,
                false,
                food.energyKcal(),
                food.nutrient(UsdaDtos.NUTRIENT_PROTEIN),
                food.nutrient(UsdaDtos.NUTRIENT_CARBS),
                food.nutrient(UsdaDtos.NUTRIENT_FAT),
                food.nutrient(UsdaDtos.NUTRIENT_FIBER));
    }

    /** Produit Open Food Facts non encore importe -> resultat de recherche. */
    private FoodSearchResultDto toDto(OpenFoodFactsDtos.Product product) {
        return new FoodSearchResultDto(
                null,
                null,
                product.code(),
                product.resolvedName(),
                product.firstBrand(),
                null,
                FoodResultSource.OPEN_FOOD_FACTS,
                false,
                product.calories(),
                product.protein(),
                product.carbs(),
                product.fat(),
                product.fiber());
    }
}
