package com.fitforge.api.training.entity;

import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.common.enums.ExperienceLevel;
import com.fitforge.api.common.enums.MuscleGroup;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

/**
 * Exercice du referentiel (catalogue partage). Reference par les seances
 * (SessionExercise) et les series realisees (SetLog). Ce n'est pas l'exercice
 * "d'un utilisateur" : c'est la definition generique (ex : "Developpe couche").
 *
 * <p>Deux origines cohabitent dans cette table :
 * <ul>
 *   <li>les exercices <b>seed</b> (migration V2) : en francais, sans video ;</li>
 *   <li>les exercices <b>importes d'ExerciseDB V2</b> (via ExerciseImportService) :
 *       avec video de demonstration, instructions detaillees, images
 *       multi-resolutions. Reconnaissables a leur {@link #externalId} non nul.</li>
 * </ul>
 * Les enums {@link #primaryMuscle} / {@link #equipment} restent la source de
 * verite pour le filtrage ; le service d'import y projette (best-effort) les
 * valeurs ExerciseDB, tout en conservant les libelles bruts a cote.
 */
@Entity
@Table(name = "exercises")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Exercise {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String name;

    /**
     * Identifiant d'origine ExerciseDB (ex : {@code exr_41n2h...}).
     * Null pour les exercices seed. Unique : garantit qu'un re-import ne cree
     * pas de doublon.
     */
    @Column(length = 64, unique = true)
    private String externalId;

    /** Groupe musculaire principal travaille (best-effort a l'import). */
    @Enumerated(EnumType.STRING)
    private MuscleGroup primaryMuscle;

    /** Materiel necessaire pour realiser l'exercice (best-effort a l'import). */
    @Enumerated(EnumType.STRING)
    private Equipment equipment;

    /**
     * Niveau requis pour realiser l'exercice correctement.
     *
     * <p>ExerciseDB ne le fournit pas : il est calcule une fois par
     * {@link com.fitforge.api.training.service.ExerciseDifficultyRules} (nom du
     * mouvement, type, materiel) puis STOCKE. Stocke et non derive a la volee,
     * pour trois raisons : le filtre « niveau » de la bibliotheque s'execute en
     * SQL, le generateur de programme IA peut le lire, et la regle ne se
     * recalcule pas a chaque affichage dans le telephone.
     */
    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private ExperienceLevel difficulty;

    /** Consignes d'execution (etapes jointes par " | "). */
    @Column(columnDefinition = "text")
    private String instructions;

    /** Lien vers une video de demonstration (MP4 servi par CDN). Champ cle. */
    @Column(columnDefinition = "text")
    private String videoUrl;

    // ─────────────────────────────────────────────────────────────────────
    //  Metadonnees ExerciseDB (aperçu / filtrage). Valeurs brutes en anglais.
    // ─────────────────────────────────────────────────────────────────────

    /** Partie du corps ExerciseDB (ex : CHEST, WAIST). Brut, pour affichage. */
    @Column(length = 64)
    private String bodyPart;

    /** Type d'exercice ExerciseDB (STRENGTH, CARDIO, STRETCHING...). */
    @Column(length = 64)
    private String exerciseType;

    /** Muscles cibles principaux, joints par ", " (ex : "OBLIQUES"). */
    @Column(columnDefinition = "text")
    private String targetMuscles;

    /** Muscles secondaires, joints par ", ". */
    @Column(columnDefinition = "text")
    private String secondaryMuscles;

    /** Mots-cles de recherche, joints par ", ". */
    @Column(columnDefinition = "text")
    private String keywords;

    // ─────────────────────────────────────────────────────────────────────
    //  Contenu pedagogique complet (endpoint detail ExerciseDB).
    // ─────────────────────────────────────────────────────────────────────

    /** Presentation generale de l'exercice. */
    @Column(columnDefinition = "text")
    private String overview;

    /** Conseils d'execution (elements joints par " | "). */
    @Column(columnDefinition = "text")
    private String exerciseTips;

    /** Variations de l'exercice (elements joints par " | "). */
    @Column(columnDefinition = "text")
    private String variations;

    // ─────────────────────────────────────────────────────────────────────
    //  Images multi-resolutions. Listes = image_url/360p ; detail = 720p.
    //  On ne charge JAMAIS la video dans les listes (perf).
    // ─────────────────────────────────────────────────────────────────────

    @Column(columnDefinition = "text")
    private String imageUrl;

    // Noms de colonnes explicites : la strategie de nommage Hibernate n'insere
    // PAS d'underscore avant un groupe de chiffres (imageUrl360p -> image_url360p),
    // ce qui ne correspondrait pas a la migration (image_url_360p).
    @Column(name = "image_url_360p", columnDefinition = "text")
    private String imageUrl360p;

    @Column(name = "image_url_480p", columnDefinition = "text")
    private String imageUrl480p;

    @Column(name = "image_url_720p", columnDefinition = "text")
    private String imageUrl720p;

    @Column(name = "image_url_1080p", columnDefinition = "text")
    private String imageUrl1080p;
}
