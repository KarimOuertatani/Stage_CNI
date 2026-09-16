package com.fitforge.api.coaching.repository;

import com.fitforge.api.coaching.entity.CoachProfile;
import com.fitforge.api.common.enums.CoachStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Acces base pour les profils coach.
 */
public interface CoachProfileRepository extends JpaRepository<CoachProfile, UUID> {

    Optional<CoachProfile> findByUserId(UUID userId);

    boolean existsByUserId(UUID userId);

    /** Annuaire : coachs d'un statut donne (APPROVED), les mieux notes d'abord. */
    List<CoachProfile> findByStatusOrderByRatingAverageDescRatingCountDesc(CoachStatus status);

    // ── Console d'administration ─────────────────────────────────

    /**
     * File d'attente de l'administrateur : les dossiers d'un statut donne, du
     * plus ancien au plus recent.
     *
     * <p>L'ordre n'est pas cosmetique. Trier du plus recent au plus ancien
     * ferait descendre les dossiers anciens hors de la premiere page a chaque
     * nouvelle inscription : un coach malchanceux pourrait attendre
     * indefiniment pendant que les arrivants passent devant lui. Le plus
     * ancien d'abord garantit que tout dossier finit par etre examine.
     */
    Page<CoachProfile> findByStatusOrderBySubmittedAtAsc(CoachStatus status, Pageable pageable);

    /** Tous statuts confondus, les plus recemment soumis d'abord. */
    Page<CoachProfile> findAllByOrderBySubmittedAtDesc(Pageable pageable);

    long countByStatus(CoachStatus status);
}
