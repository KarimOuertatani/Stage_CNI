package com.fitforge.api.training.repository;

import com.fitforge.api.training.entity.SetLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Acces base aux series realisees, pour les questions qui portent sur UN
 * exercice a travers toutes les seances (« ou en etais-je la derniere fois ? »).
 */
public interface SetLogRepository extends JpaRepository<SetLog, UUID> {

    /**
     * Date de la derniere seance ou l'adherent a REELLEMENT realise cet exercice.
     *
     * <p>Seules les series terminees comptent : une serie abandonnee n'est pas
     * une reference de charge, et la proposer en pre-remplissage ferait
     * regresser l'adherent sans qu'il comprenne pourquoi.
     */
    @Query("""
            SELECT MAX(s.workoutLog.performedOn) FROM SetLog s
            WHERE s.workoutLog.user.id = :userId
              AND s.exercise.id = :exerciseId
              AND s.completed = true
            """)
    Optional<LocalDate> findLastPerformedOn(@Param("userId") UUID userId,
                                            @Param("exerciseId") UUID exerciseId);

    /**
     * Les series realisees sur cet exercice a une date donnee, dans l'ordre.
     *
     * <p>Si l'exercice a ete travaille en deux fois le meme jour, les deux
     * groupes de series remontent — et c'est voulu : « la derniere fois » se
     * compte en journees d'entrainement, pas en enregistrements.
     */
    @Query("""
            SELECT s FROM SetLog s
            WHERE s.workoutLog.user.id = :userId
              AND s.exercise.id = :exerciseId
              AND s.workoutLog.performedOn = :day
              AND s.completed = true
            ORDER BY s.setNumber ASC
            """)
    List<SetLog> findSetsOnDay(@Param("userId") UUID userId,
                               @Param("exerciseId") UUID exerciseId,
                               @Param("day") LocalDate day);
}
