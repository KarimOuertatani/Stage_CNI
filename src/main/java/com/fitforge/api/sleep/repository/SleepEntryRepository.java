package com.fitforge.api.sleep.repository;

import com.fitforge.api.sleep.entity.SleepEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Acces base au journal de sommeil.
 */
public interface SleepEntryRepository extends JpaRepository<SleepEntry, UUID> {

    /**
     * La nuit d'une date precise.
     *
     * <p>C'est la requete de l'upsert : renvoyer sa nuit corrige la ligne
     * existante au lieu d'en creer une seconde.
     */
    Optional<SleepEntry> findByUserIdAndSleepDate(UUID userId, LocalDate sleepDate);

    /**
     * Les nuits d'une plage de dates, de la plus ancienne a la plus recente.
     *
     * <p>Ordre croissant a dessein : l'histogramme se lit de gauche a droite,
     * du lundi au dimanche. Trier a l'envers puis inverser cote service serait
     * du travail en double.
     */
    List<SleepEntry> findByUserIdAndSleepDateBetweenOrderBySleepDateAsc(
            UUID userId, LocalDate from, LocalDate to);

    /** La derniere nuit saisie — la tuile de l'accueil, a chaque ouverture. */
    Optional<SleepEntry> findTopByUserIdOrderBySleepDateDesc(UUID userId);

    /**
     * Duree moyenne des nuits depuis une date, en minutes.
     *
     * <p>Calculee par la base et non en Java : on ne charge pas sept a trente
     * lignes pour n'en garder qu'un nombre. Renvoie {@code null} si aucune nuit
     * n'a ete saisie sur la periode — a distinguer de zero, qui voudrait dire
     * « il ne dort pas ».
     */
    @Query("""
            SELECT AVG(s.durationMinutes) FROM SleepEntry s
            WHERE s.user.id = :userId AND s.sleepDate >= :since
            """)
    Double averageDurationSince(@Param("userId") UUID userId,
                                @Param("since") LocalDate since);
}
