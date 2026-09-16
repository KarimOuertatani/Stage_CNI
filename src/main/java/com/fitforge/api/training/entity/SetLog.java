package com.fitforge.api.training.entity;

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
 * Une serie REELLEMENT realisee dans une seance (poids et reps effectifs).
 * Rattachee au WorkoutLog et a l'exercice concerne. Le volume d'une serie
 * (reps * poids) sert au calcul du score d'entrainement.
 */
@Entity
@Table(name = "set_logs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SetLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Seance (log) a laquelle appartient la serie (LAZY). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "workout_log_id", nullable = false)
    private WorkoutLog workoutLog;

    /** Exercice realise (LAZY). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "exercise_id", nullable = false)
    private Exercise exercise;

    private Integer setNumber;    // numero de la serie (1, 2, 3...)
    private Integer reps;         // repetitions realisees
    private Double weightKg;      // charge utilisee

    /** Serie terminee (vs abandonnee). */
    @Builder.Default
    private boolean completed = true;
}
