package com.fitforge.api.score.entity;

import com.fitforge.api.user.entity.User;
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

import java.time.LocalDate;
import java.util.UUID;

/**
 * Score d'entrainement calcule (une ligne par semaine).
 * Resume la charge et l'assiduite de l'adherent sous forme d'une note 0-100
 * accompagnee d'une phrase d'analyse (insight).
 */
@Entity
@Table(name = "training_scores")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TrainingScore {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Adherent concerne (LAZY). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** Date de reference du score : le lundi de la semaine calculee. */
    @Column(nullable = false)
    private LocalDate scoreDate;

    private Integer score;              // note 0..100
    private Double weeklyVolumeKg;      // volume total souleve (Σ reps * poids)
    private Integer sessionsCompleted;  // seances de la semaine
    private Double consistencyRate;     // % d'assiduite vs objectif (0..1)

    @Column(length = 500)
    private String insight;             // phrase generee, ex : "Volume en hausse de 8%"
}
