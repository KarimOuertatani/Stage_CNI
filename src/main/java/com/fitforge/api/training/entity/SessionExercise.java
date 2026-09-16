package com.fitforge.api.training.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

/**
 * Exercice PLACE dans une seance : table de liaison enrichie entre
 * WorkoutSession et Exercise, portant les objectifs (series/reps/poids/repos).
 */
@Entity
@Table(name = "session_exercises")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SessionExercise {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Seance a laquelle appartient cette ligne (LAZY). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "session_id", nullable = false)
    private WorkoutSession session;

    /** Exercice du referentiel place ici (LAZY). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "exercise_id", nullable = false)
    private Exercise exercise;

    private Integer targetSets;       // nombre de series cibles
    private Integer targetReps;       // repetitions cibles par serie
    private Double targetWeightKg;    // charge cible
    private Integer restSeconds;      // repos entre series
    private Integer orderIndex;       // ordre dans la seance

    /**
     * Consigne d'execution pour CET exercice dans CETTE seance.
     *
     * <p>« Descends en 3 secondes », « garde 2 repetitions en reserve », « si
     * le genou tire, reduis l'amplitude ». C'est ce qui distingue un programme
     * ecrit par un coach d'un tableau de series et de repetitions.
     *
     * <p>Renseignee par les programmes generes ; reste {@code null} sur les
     * programmes composes a la main.
     */
    @Column(length = 300)
    private String notes;
}
