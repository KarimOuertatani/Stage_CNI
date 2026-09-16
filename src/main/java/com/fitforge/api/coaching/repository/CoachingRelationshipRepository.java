package com.fitforge.api.coaching.repository;

import com.fitforge.api.coaching.entity.CoachingRelationship;
import com.fitforge.api.common.enums.CoachingStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Acces base pour les relations de suivi adherent<->coach.
 */
public interface CoachingRelationshipRepository extends JpaRepository<CoachingRelationship, UUID> {

    /** Relation existante entre ce coach et cet adherent (quelle qu'en soit le statut). */
    Optional<CoachingRelationship> findByCoachIdAndMemberId(UUID coachId, UUID memberId);

    /** Cote coach : toutes ses relations (demandes + suivis), plus recentes d'abord. */
    List<CoachingRelationship> findByCoachIdOrderByCreatedAtDesc(UUID coachId);

    /** Cote coach : relations d'un statut donne (ex : PENDING pour les demandes). */
    List<CoachingRelationship> findByCoachIdAndStatusOrderByCreatedAtDesc(UUID coachId, CoachingStatus status);

    /** Cote adherent : ses relations (ses coachs + demandes en cours). */
    List<CoachingRelationship> findByMemberIdOrderByCreatedAtDesc(UUID memberId);

    /** Nombre d'adherents actifs suivis par ce coach. */
    long countByCoachIdAndStatus(UUID coachId, CoachingStatus status);

    /**
     * Ids des interlocuteurs de chat d'un utilisateur, quel que soit son role
     * dans la relation : le coach de ses adherents, l'adherent de ses coachs.
     *
     * <p>Utilise par la presence pour savoir <b>a qui</b> annoncer qu'un
     * utilisateur vient de se connecter ou de se deconnecter — jamais a tout
     * le monde.
     */
    @Query("""
            select case when r.coach.id = :userId then r.member.id else r.coach.id end
            from CoachingRelationship r
            where r.status = :status
              and (r.coach.id = :userId or r.member.id = :userId)
            """)
    List<UUID> findPartnerIds(@Param("userId") UUID userId,
                              @Param("status") CoachingStatus status);

    /**
     * Vrai si deux comptes sont lies par une relation de ce statut, dans un
     * sens ou dans l'autre. Controle d'acces de la consultation de presence.
     */
    @Query("""
            select count(r) > 0 from CoachingRelationship r
            where r.status = :status
              and ((r.coach.id = :a and r.member.id = :b)
                or (r.coach.id = :b and r.member.id = :a))
            """)
    boolean areLinked(@Param("a") UUID a,
                      @Param("b") UUID b,
                      @Param("status") CoachingStatus status);
}
