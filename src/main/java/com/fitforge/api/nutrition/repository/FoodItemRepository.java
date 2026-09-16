package com.fitforge.api.nutrition.repository;

import com.fitforge.api.nutrition.entity.FoodItem;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Acces au catalogue d'aliments (cache local des donnees USDA).
 */
public interface FoodItemRepository extends JpaRepository<FoodItem, UUID> {

    /**
     * Cle du cache : un aliment USDA n'est importe qu'une seule fois.
     * Utilise avant tout appel a l'API externe.
     */
    Optional<FoodItem> findByUsdaFdcId(Long usdaFdcId);

    /** Aliments deja en cache parmi une liste d'ids USDA (1 seule requete). */
    List<FoodItem> findByUsdaFdcIdIn(List<Long> usdaFdcIds);

    /**
     * Cle du cache cote Open Food Facts : un produit emballe n'est importe
     * qu'une seule fois, quel que soit le nombre d'adherents qui l'ajoutent.
     */
    Optional<FoodItem> findByOffCode(String offCode);

    /** Produits deja en cache parmi une liste de codes-barres (1 seule requete). */
    List<FoodItem> findByOffCodeIn(List<String> offCodes);

    /**
     * Recherche locale par libelle (insensible a la casse), <b>dans les deux
     * langues</b> : le catalogue contient le libelle USDA d'origine (anglais)
     * et sa traduction francaise.
     *
     * <p>On interroge les deux colonnes avec les deux termes plutot que de
     * supposer laquelle correspond a la saisie : un adherent peut taper
     * « poulet » (trouve dans {@code nameFr}) comme « chicken » (trouve dans
     * {@code name}), et un aliment personnalise n'a pas de traduction.
     *
     * @param french saisie originale de l'adherent
     * @param english la meme saisie passee au lexique FR -&gt; EN
     */
    @Query("""
            select f from FoodItem f
            where lower(coalesce(f.nameFr, f.name)) like lower(concat('%', :french, '%'))
               or lower(f.name) like lower(concat('%', :english, '%'))
            order by length(f.name) asc
            """)
    List<FoodItem> searchByName(@Param("french") String french,
                                @Param("english") String english,
                                Pageable pageable);

    /**
     * Aliments les plus consommes par un adherent (« Mes aliments recents »).
     * Permet de re-ajouter un aliment habituel sans aucune recherche.
     */
    @Query("""
            select e.foodItem from NutritionEntry e
            where e.user.id = :userId and e.foodItem is not null
            group by e.foodItem
            order by max(e.consumedOn) desc, count(e) desc
            """)
    List<FoodItem> findMostUsedByUser(@Param("userId") UUID userId, Pageable pageable);
}
