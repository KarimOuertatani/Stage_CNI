package com.fitforge.api.training.entity;

import com.fitforge.api.user.entity.User;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Une seance REELLEMENT effectuee par l'adherent (le coeur du tracking).
 * Peut etre rattachee a une seance-type (session) ou etre une seance libre
 * (session = null). Contient les series realisees (SetLog).
 */
@Entity
@Table(name = "workout_logs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WorkoutLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Adherent qui a fait la seance (LAZY). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** Seance-type suivie (optionnel : une seance libre n'en a pas). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "session_id")
    private WorkoutSession session;

    /** Date a laquelle la seance a ete realisee. */
    @Column(nullable = false)
    private LocalDate performedOn;

    private Integer durationMinutes;
    private Integer rpe;               // ressenti d'effort 1..10

    /** Series realisees pendant la seance. cascade ALL + orphanRemoval. */
    @OneToMany(mappedBy = "workoutLog", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<SetLog> sets = new ArrayList<>();
}
