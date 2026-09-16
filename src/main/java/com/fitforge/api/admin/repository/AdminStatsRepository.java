package com.fitforge.api.admin.repository;

import com.fitforge.api.common.enums.Role;
import com.fitforge.api.user.entity.User;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Requetes d'agregation de la console : compteurs du tableau de bord et
 * activite d'un membre.
 *
 * <h2>Pourquoi un repository a part, qui traverse plusieurs domaines</h2>
 * Ces requetes comptent des seances, des repas, des nuits et des comptes -- des
 * entites qui appartiennent a quatre domaines differents. Les repartir dans
 * {@code WorkoutLogRepository}, {@code NutritionEntryRepository} et les autres
 * aurait deux inconvenients : chaque domaine porterait des methodes qui ne
 * servent qu'a l'administration, et le service de statistiques devrait injecter
 * huit repositories pour produire un seul ecran.
 *
 * <p>Il etend {@link Repository} et non {@code JpaRepository} : on ne veut ni
 * {@code save}, ni {@code delete}, ni {@code findAll} sur un composant dont le
 * seul role est de compter. Le type le plus etroit qui fonctionne est celui qui
 * ferme le plus de mauvaises utilisations.
 */
public interface AdminStatsRepository extends Repository<User, UUID> {

    // ── Comptes ──────────────────────────────────────────────────

    @Query("select count(u) from User u where u.role = :role")
    long countByRole(@Param("role") Role role);

    @Query("select count(u) from User u where u.role = :role and u.enabled = :enabled")
    long countByRoleAndEnabled(@Param("role") Role role, @Param("enabled") boolean enabled);

    @Query("select count(u) from User u where u.createdAt >= :since")
    long countUsersCreatedSince(@Param("since") Instant since);

    /**
     * Utilisateurs « actifs » : ceux qui se sont connectes depuis une date.
     *
     * <p>On s'appuie sur {@code lastLoginAt} et non sur {@code lastSeenAt} :
     * ce dernier est ecrit par la presence WebSocket, qui ne concerne que les
     * ecrans de chat. Un adherent qui logue ses seances tous les jours sans
     * jamais ouvrir une conversation aurait un {@code lastSeenAt} tres ancien
     * et serait compte comme inactif.
     */
    @Query("select count(u) from User u where u.lastLoginAt >= :since")
    long countActiveSince(@Param("since") Instant since);

    /**
     * Inscriptions jour par jour depuis une date, pour la courbe du tableau de
     * bord.
     *
     * <p>Le regroupement est fait <b>par la base</b>. Charger les comptes pour
     * les grouper en Java transporterait toutes les lignes sur le reseau afin
     * d'en tirer trente nombres -- et le cout grandirait avec la base, alors
     * que le resultat, lui, garde toujours la meme taille.
     *
     * <p>Renvoie des paires {@code [LocalDate, Long]}. Les jours sans aucune
     * inscription sont <b>absents</b> : c'est au service de completer les
     * trous, sinon la courbe sauterait les jours creux au lieu de les afficher
     * a zero.
     */
    @Query("""
            select cast(u.createdAt as localdate) as day, count(u)
              from User u
             where u.createdAt >= :since
             group by cast(u.createdAt as localdate)
             order by day
            """)
    List<Object[]> countRegistrationsPerDaySince(@Param("since") Instant since);

    // ── Activite d'un membre ─────────────────────────────────────

    @Query("select count(w) from WorkoutLog w where w.user.id = :userId")
    long countWorkoutLogs(@Param("userId") UUID userId);

    @Query("select max(w.performedOn) from WorkoutLog w where w.user.id = :userId")
    LocalDate lastWorkoutDate(@Param("userId") UUID userId);

    @Query("select count(n) from NutritionEntry n where n.user.id = :userId")
    long countNutritionEntries(@Param("userId") UUID userId);

    @Query("select count(s) from SleepEntry s where s.user.id = :userId")
    long countSleepEntries(@Param("userId") UUID userId);

    @Query("select count(p) from WorkoutProgram p where p.user.id = :userId")
    long countPrograms(@Param("userId") UUID userId);

    // ── Volumes globaux ──────────────────────────────────────────

    @Query("select count(w) from WorkoutLog w where w.performedOn >= :since")
    long countWorkoutLogsSince(@Param("since") LocalDate since);

    @Query("select count(n) from NutritionEntry n where n.consumedOn >= :since")
    long countNutritionEntriesSince(@Param("since") LocalDate since);

    @Query("select count(s) from SleepEntry s where s.sleepDate >= :since")
    long countSleepEntriesSince(@Param("since") LocalDate since);
}
