package com.fitforge.api.user.entity;

import com.fitforge.api.common.enums.ActivityLevel;
import com.fitforge.api.common.enums.DietaryPreference;
import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.common.enums.ExperienceLevel;
import com.fitforge.api.common.enums.FitnessGoal;
import com.fitforge.api.common.enums.Gender;
import com.fitforge.api.common.enums.UnitSystem;
import com.fitforge.api.common.enums.WorkoutLocation;
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
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Profil physique et sportif de l'adherent : toutes les infos "corps & sport".
 * Relation 1-1 avec {@link User}. Contient la valeur ACTUELLE des mesures
 * (l'historique, lui, est dans BodyMeasurement).
 *
 * Les champs age / bmi / tdee sont DERIVES : recalcules par ProfileService a
 * chaque mise a jour (jamais saisis directement par l'utilisateur).
 */
@Entity
@Table(name = "user_profiles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Lien 1-1 vers le compte. LAZY : on ne charge le User que si besoin. */
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    // -------------------- Identite physique --------------------

    /** Date de naissance : l'age se calcule a partir de ca (jamais saisi). */
    private LocalDate birthDate;

    @Enumerated(EnumType.STRING)
    private Gender gender;

    private Double heightCm;
    private Double currentWeightKg;   // poids actuel (derniere pesee)
    private Double targetWeightKg;    // poids vise

    // -------------------- Objectif & mode de vie --------------------

    @Enumerated(EnumType.STRING)
    private FitnessGoal goal;

    /** Rythme de vie : facteur multiplicateur du BMR pour le TDEE. */
    @Enumerated(EnumType.STRING)
    private ActivityLevel activityLevel;

    @Enumerated(EnumType.STRING)
    private ExperienceLevel experienceLevel;

    private Integer weeklyWorkoutTarget;   // nb de seances visees / semaine

    @Enumerated(EnumType.STRING)
    private WorkoutLocation preferredLocation;

    /**
     * Jours d'entrainement preferes (LUNDI..DIMANCHE).
     * Stockes dans une table dediee via @ElementCollection.
     */
    @ElementCollection(targetClass = DayOfWeek.class)
    @CollectionTable(name = "user_workout_days", joinColumns = @JoinColumn(name = "profile_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "day")
    @Builder.Default
    private List<DayOfWeek> preferredWorkoutDays = new ArrayList<>();

    /** Materiel dont l'adherent dispose (pour adapter les programmes). */
    @ElementCollection(targetClass = Equipment.class)
    @CollectionTable(name = "user_equipment", joinColumns = @JoinColumn(name = "profile_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "equipment")
    @Builder.Default
    private List<Equipment> availableEquipment = new ArrayList<>();

    // -------------------- Sante / blessures --------------------

    /** Blessures declarees, ex : "genou droit", "epaule gauche". */
    @ElementCollection
    @CollectionTable(name = "user_injuries", joinColumns = @JoinColumn(name = "profile_id"))
    @Column(name = "injury")
    @Builder.Default
    private List<String> injuries = new ArrayList<>();

    @Column(length = 1000)
    private String medicalNotes;   // maladies, contre-indications...

    // -------------------- Nutrition & habitudes --------------------

    @Enumerated(EnumType.STRING)
    private DietaryPreference dietaryPreference;

    /** Allergies, ex : "arachides", "lactose". */
    @ElementCollection
    @CollectionTable(name = "user_allergies", joinColumns = @JoinColumn(name = "profile_id"))
    @Column(name = "allergy")
    @Builder.Default
    private List<String> allergies = new ArrayList<>();

    private Integer dailyCalorieTarget;   // sinon calcule depuis le TDEE
    private Integer waterTargetMl;
    private Double averageSleepHours;     // impacte la recuperation

    // -------------------- Preferences applicatives --------------------

    @Enumerated(EnumType.STRING)
    @Builder.Default
    private UnitSystem unitSystem = UnitSystem.METRIQUE;

    @Builder.Default
    private String preferredLanguage = "fr";   // fr, ar, en

    // -------------------- Calcules / derives --------------------

    private Double bmi;      // IMC calcule
    private Integer tdee;    // depense energetique estimee (kcal/j)
    private Integer age;     // age calcule depuis birthDate

    // -------------------- Onboarding --------------------

    /** Profil rempli au 1er lancement ? */
    @Column(nullable = false)
    @Builder.Default
    private boolean onboardingCompleted = false;

    @UpdateTimestamp
    private Instant updatedAt;
}
