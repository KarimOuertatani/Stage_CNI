package com.fitforge.api.user.repository;

import com.fitforge.api.common.enums.Role;
import com.fitforge.api.user.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

/**
 * Acces base pour les comptes. Spring Data JPA genere l'implementation.
 */
public interface UserRepository extends JpaRepository<User, UUID> {

    /** Recherche par email (sert a la connexion et au chargement de l'utilisateur). */
    Optional<User> findByEmail(String email);

    /** Verifie l'unicite de l'email avant inscription. */
    boolean existsByEmail(String email);

    /**
     * Horodate la derniere activite temps reel (connexion / deconnexion
     * WebSocket).
     *
     * <p>UPDATE cible plutot que chargement de l'entite : l'operation est
     * declenchee a chaque ouverture et fermeture de session WebSocket, elle
     * doit rester la plus legere possible et ne jamais toucher au reste du
     * compte.
     */
    @Modifying
    @Query("update User u set u.lastSeenAt = :instant where u.id = :id")
    void touchLastSeen(@Param("id") UUID id, @Param("instant") Instant instant);

    // ── Console d'administration ─────────────────────────────────

    /**
     * Recherche paginee des comptes, avec filtres facultatifs.
     *
     * <h2>🪤 Pourquoi le motif de recherche est construit en Java</h2>
     * La premiere version passait le texte brut et le rendait facultatif de la
     * meme facon que les autres filtres :
     *
     * <pre>{@code
     * and (:query is null
     *      or lower(u.fullName) like lower(concat('%', :query, '%'))
     *      or lower(u.email)    like lower(concat('%', :query, '%')))
     * }</pre>
     *
     * <p>Elle echouait systematiquement, avec une erreur qui ne dit pas du tout
     * ce qui se passe :
     *
     * <pre>ERROR: function lower(bytea) does not exist</pre>
     *
     * <p>La cause : un parametre lie a {@code null} n'a <b>aucun type</b> pour
     * PostgreSQL. Place dans un {@code concat(...)} lui-meme passe a
     * {@code lower(...)}, le serveur doit deviner — et il retombe sur
     * {@code bytea}, pour lequel {@code lower} n'existe pas. Le filtre etait
     * donc casse <b>meme quand aucune recherche n'etait demandee</b>, puisque
     * c'est precisement le cas ou le parametre vaut {@code null}.
     *
     * <p>La correction supprime le probleme a la racine plutot que d'ajouter un
     * transtypage : le service construit le motif ({@code %texte%}, ou
     * {@code %} quand rien n'est cherche), qui n'est donc <b>jamais nul</b>. Le
     * {@code lower()} ne s'applique plus qu'a des colonnes, dont le type ne fait
     * aucun doute.
     *
     * <p>Les filtres {@code role} et {@code enabled} gardent leur forme
     * {@code :x is null or ...} : ils sont compares a une colonne typee, ce qui
     * suffit a PostgreSQL pour inferer leur type.
     *
     * <p>Le parametre {@code enabled} est un {@code Boolean} et non un
     * {@code boolean} — c'est ce qui permet au filtre « actif / suspendu »
     * d'avoir trois etats : actif, suspendu, et « peu importe ».
     *
     * @param pattern motif SQL deja construit et deja en minuscules,
     *                jamais {@code null} (voir {@code AdminUserService.list})
     */
    @Query("""
            select u from User u
             where (:role is null or u.role = :role)
               and (:enabled is null or u.enabled = :enabled)
               and (lower(u.fullName) like :pattern or lower(u.email) like :pattern)
            """)
    Page<User> search(@Param("role") Role role,
                      @Param("enabled") Boolean enabled,
                      @Param("pattern") String pattern,
                      Pageable pageable);
}
