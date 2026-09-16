package com.fitforge.api.coaching.entity;

import com.fitforge.api.common.enums.CoachSpecialty;
import com.fitforge.api.common.enums.CoachStatus;
import com.fitforge.api.user.entity.User;
import jakarta.persistence.CascadeType;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
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
import jakarta.persistence.OneToOne;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Profil professionnel d'un COACH (1-1 avec un {@link User} de role COACH).
 * Regroupe les informations metier : specialites, experience, tarif, bio, et
 * les listes riches (certifications, formations, experiences) qui construisent
 * le CV du coach consultable par les adherents.
 */
@Entity
@Table(name = "coach_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CoachProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Compte utilisateur associe (role COACH). */
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    /** Accroche courte affichee dans l'annuaire (ex : "Coach force & muscu"). */
    private String headline;

    /** Presentation detaillee du coach. */
    @Column(length = 2000)
    private String bio;

    /** Nombre d'annees d'experience dans le domaine. */
    private Integer yearsExperience;

    /** Tarif horaire indicatif (optionnel). */
    private Double hourlyRate;

    /** Ville / zone d'exercice (optionnel). */
    private String city;

    /** Statut de moderation (APPROVED par defaut pour l'instant). */
    /**
     * Etat de la candidature. Par defaut {@link CoachStatus#DRAFT} : un coach
     * qui vient de s'inscrire n'a rien depose, il n'est donc ni approuve ni en
     * attente d'examen. (Cette valeur etait APPROVED avant la mise en place de
     * la validation par l'administration : tout coach etait actif des la
     * creation de son compte, sans qu'aucun justificatif ne soit demande.)
     */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private CoachStatus status = CoachStatus.DRAFT;

    /** Horodatage de la soumission du dossier. Null tant qu'il est en DRAFT. */
    @Column(name = "submitted_at")
    private Instant submittedAt;

    /** Horodatage de la decision de l'administrateur (approbation ou refus). */
    @Column(name = "reviewed_at")
    private Instant reviewedAt;

    /**
     * Administrateur ayant tranche. Conserve pour la tracabilite : une decision
     * de moderation sans auteur n'est pas verifiable a posteriori.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reviewed_by")
    private User reviewedBy;

    /**
     * Motif du refus, <b>affiche tel quel au coach</b>. C'est ce qui rend le
     * refus corrigeable : « photo illisible » se repare, « refuse » ne se repare
     * pas. Egalement renseigne lors d'une suspension.
     */
    @Column(name = "rejection_reason", length = 1000)
    private String rejectionReason;

    /** Le coach accepte-t-il de nouveaux adherents ? */
    @Column(nullable = false)
    @Builder.Default
    private boolean acceptingClients = true;

    /** Note moyenne (0..5) et nombre d'avis — reserves pour une future feature. */
    @Column(nullable = false)
    @Builder.Default
    private double ratingAverage = 0.0;

    @Column(nullable = false)
    @Builder.Default
    private int ratingCount = 0;

    /** Specialites du coach (ElementCollection en table dediee). */
    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "coach_specialties", joinColumns = @JoinColumn(name = "coach_profile_id"))
    @Column(name = "specialty")
    @Enumerated(EnumType.STRING)
    @Builder.Default
    private Set<CoachSpecialty> specialties = new HashSet<>();

    @OneToMany(mappedBy = "coachProfile", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("year DESC")
    @Builder.Default
    private List<CoachCertification> certifications = new ArrayList<>();

    @OneToMany(mappedBy = "coachProfile", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("year DESC")
    @Builder.Default
    private List<CoachEducation> educations = new ArrayList<>();

    @OneToMany(mappedBy = "coachProfile", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("startYear DESC")
    @Builder.Default
    private List<CoachExperienceItem> experiences = new ArrayList<>();

    /**
     * Justificatifs deposes a l'appui de la candidature.
     *
     * <p>Contrairement aux trois listes ci-dessus, celle-ci n'est <b>pas</b>
     * remplacee en bloc par {@code upsertMyProfile}. Les certifications sont du
     * texte que le coach reecrit librement ; un justificatif est un fichier sur
     * disque, ajoute et supprime un par un. Les vider a chaque enregistrement du
     * profil effacerait les pieces du dossier a la premiere correction de
     * biographie.
     */
    @OneToMany(mappedBy = "coachProfile", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("uploadedAt ASC")
    @Builder.Default
    private List<CoachDocument> documents = new ArrayList<>();
}
