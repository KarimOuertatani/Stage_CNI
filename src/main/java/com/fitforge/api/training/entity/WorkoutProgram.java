package com.fitforge.api.training.entity;

import com.fitforge.api.common.enums.ExperienceLevel;
import com.fitforge.api.common.enums.FitnessGoal;
import com.fitforge.api.user.entity.User;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Programme d'entrainement d'un adherent (ex : "Prise de masse 4 semaines").
 * Contient plusieurs seances-types (WorkoutSession).
 */
@Entity
@Table(name = "workout_programs")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WorkoutProgram {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * Proprietaire du programme (LAZY). NULLABLE : les programmes "prets"
     * (modeles fournis par l'application, comme Push/Pull/Legs) n'appartiennent
     * a personne (user = null) et sont visibles par tous les adherents.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    /**
     * Auteur du programme s'il a ete cree par quelqu'un d'autre que le
     * proprietaire : typiquement un COACH qui compose un programme pour son
     * adherent. null = programme cree par l'adherent lui-meme (ou modele).
     * Un programme est modifiable par son proprietaire OU par son createur.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by")
    private User createdBy;

    private String title;

    /** Presentation courte du programme (surtout utile pour les modeles). */
    @Column(length = 500)
    private String description;

    @Enumerated(EnumType.STRING)
    private FitnessGoal goal;

    /** Niveau conseille (utile pour presenter les modeles). */
    @Enumerated(EnumType.STRING)
    private ExperienceLevel experienceLevel;

    private Integer durationWeeks;

    /** Programme modele (reutilisable) plutot que personnel. */
    @Builder.Default
    private boolean isTemplate = false;

    /**
     * Programme compose par l'<b>IA FitForge</b> a partir du questionnaire de
     * l'adherent et de son profil.
     *
     * <p>Ce drapeau joue le meme role que {@link #createdBy} pour un coach : il
     * dit <b>qui a compose</b> le programme. L'application affiche « Cree avec
     * l'IA FitForge » la ou elle afficherait « Cree par &lt;coach&gt; ».
     *
     * <p>Un programme genere reste un programme <b>ordinaire</b> : il se
     * modifie, s'enrichit d'une seance, se supprime, et sert de support aux
     * seances loguees. Seule son origine change.
     */
    @Column(name = "generated_by_ai", nullable = false)
    @Builder.Default
    private boolean generatedByAi = false;

    /**
     * Le mot de l'IA : pourquoi ce decoupage, ce volume, ces exercices.
     *
     * <p>Ce n'est pas un ornement. Un programme dont on comprend la logique se
     * suit ; une liste d'exercices tombee du ciel se subit. C'est aussi ce qui
     * rend le resultat verifiable par l'adherent — et par son coach.
     */
    @Column(name = "ai_rationale", columnDefinition = "text")
    private String aiRationale;

    /** Date de generation ({@code null} pour un programme non genere). */
    @Column(name = "ai_generated_at")
    private Instant aiGeneratedAt;

    /**
     * Seances du programme. cascade = ALL + orphanRemoval : les seances vivent
     * et meurent avec le programme. @OrderBy pour un ordre d'affichage stable.
     */
    @OneToMany(mappedBy = "program", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("orderIndex ASC")
    @Builder.Default
    private List<WorkoutSession> sessions = new ArrayList<>();
}
