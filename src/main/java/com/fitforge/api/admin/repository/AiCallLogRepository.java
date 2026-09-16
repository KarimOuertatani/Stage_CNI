package com.fitforge.api.admin.repository;

import com.fitforge.api.admin.entity.AiCallLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** Agregation des appels aux modeles de langage, pour la page de supervision. */
public interface AiCallLogRepository extends JpaRepository<AiCallLog, UUID> {

    /**
     * Une ligne par fonction : appels, echecs, latence moyenne et maximale,
     * depuis une date.
     *
     * <p>Tout est agrege <b>par la base</b>. Charger les lignes pour les
     * parcourir en Java ferait transiter des dizaines de milliers
     * d'enregistrements afin d'en tirer cinq totaux -- et le cout grandirait
     * indefiniment, alors que le resultat garde toujours la meme taille.
     *
     * <p>La latence moyenne n'est calculee que sur les appels <b>reussis</b>.
     * Un echec reseau qui rend la main en 30 ms ferait chuter la moyenne et
     * donnerait l'illusion d'un service rapide au moment precis ou il tombe.
     *
     * <p>Renvoie {@code [AiFeature, long total, long failures, Double avgMs,
     * Long maxMs]}.
     */
    @Query("""
            select l.feature,
                   count(l),
                   sum(case when l.success = false then 1L else 0L end),
                   avg(case when l.success = true then l.latencyMs else null end),
                   max(case when l.success = true then l.latencyMs else null end)
              from AiCallLog l
             where l.createdAt >= :since
             group by l.feature
            """)
    List<Object[]> aggregateSince(@Param("since") Instant since);

    /** Les derniers echecs, pour afficher ce qui ne va pas plutot qu'un taux. */
    @Query("""
            select l from AiCallLog l
             where l.success = false
             order by l.createdAt desc
            """)
    List<AiCallLog> recentFailures(org.springframework.data.domain.Pageable pageable);

    @Query("select count(l) from AiCallLog l where l.createdAt >= :since")
    long countSince(@Param("since") Instant since);

    @Query("select count(l) from AiCallLog l where l.createdAt >= :since and l.success = false")
    long countFailuresSince(@Param("since") Instant since);

    /**
     * Purge des traces anterieures a une date.
     *
     * <p>Ce journal grossit a chaque appel et n'a aucune valeur historique
     * au-dela de quelques semaines : on y cherche « est-ce que ca marche en ce
     * moment », jamais « combien d'appels en mars ». Sans purge, la table
     * deviendrait la plus volumineuse de la base pour alimenter une seule page.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("delete from AiCallLog l where l.createdAt < :before")
    int deleteOlderThan(@Param("before") Instant before);
}
