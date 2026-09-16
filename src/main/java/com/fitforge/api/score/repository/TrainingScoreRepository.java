package com.fitforge.api.score.repository;

import com.fitforge.api.score.entity.TrainingScore;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Acces base pour les scores d'entrainement.
 */
public interface TrainingScoreRepository extends JpaRepository<TrainingScore, UUID> {

    /** Score le plus recent d'un adherent. */
    Optional<TrainingScore> findTopByUserIdOrderByScoreDateDesc(UUID userId);

    /** Historique des scores, du plus recent au plus ancien (limite par Pageable). */
    List<TrainingScore> findByUserIdOrderByScoreDateDesc(UUID userId, Pageable pageable);

    /** Score deja calcule pour une semaine donnee (pour le recalculer/mettre a jour). */
    Optional<TrainingScore> findByUserIdAndScoreDate(UUID userId, LocalDate scoreDate);
}
