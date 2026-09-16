package com.fitforge.api.training.ai.dto;

import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.common.enums.ExperienceLevel;
import com.fitforge.api.common.enums.FitnessGoal;
import com.fitforge.api.common.enums.MuscleGroup;
import com.fitforge.api.common.enums.WorkoutLocation;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * Le questionnaire : ce que l'adherent dit de son entrainement.
 *
 * <h2>Pourquoi ces questions et pas d'autres</h2>
 *
 * <p>Le profil de l'adherent est deja connu du serveur (objectif, niveau,
 * materiel, blessures) et il est joint automatiquement au brief. Le
 * questionnaire ne redemande donc <b>rien</b> par principe : il ne porte que ce
 * qui <b>change la structure du programme</b> et qui, soit n'existe pas au
 * profil, soit peut differer pour ce programme-la.
 *
 * <ul>
 *   <li><b>Combien de jours et combien de temps</b> — c'est ce qui decide du
 *       decoupage. Trois jours donnent un full body, cinq un push/pull/legs
 *       etendu. Aucune autre reponse n'a autant d'effet.</li>
 *   <li><b>Les charges de reference</b> — sans elles, un programme ne peut
 *       proposer que « 4 x 8 » et laisser l'adherent deviner le poids. Avec
 *       elles, les charges cibles sont des vrais nombres.</li>
 *   <li><b>Les zones a prioriser</b> — deux adherents avec le meme objectif
 *       n'ont pas les memes points faibles.</li>
 *   <li><b>Les contraintes</b> — champ libre. C'est la que remonte ce qu'aucune
 *       liste ne prevoit : « pas de course, je suis en appartement », « je
 *       n'ai que 20 minutes le vendredi ».</li>
 * </ul>
 *
 * <p>Les champs {@code goal}, {@code experienceLevel}, {@code location} et
 * {@code equipment} sont pre-remplis cote application depuis le profil : ils
 * sont <b>modifiables</b> pour ce programme sans reecrire le profil.
 */
@Schema(description = "Questionnaire de generation d'un programme par l'IA FitForge")
public record GenerateProgramRequest(

        @Schema(description = "Objectif vise par CE programme", example = "PRISE_MASSE")
        @NotNull FitnessGoal goal,

        @Schema(description = "Niveau de l'adherent en musculation", example = "INTERMEDIAIRE")
        @NotNull ExperienceLevel experienceLevel,

        @Schema(description = "Nombre de seances par semaine", example = "4")
        @NotNull @Min(1) @Max(7) Integer daysPerWeek,

        @Schema(description = "Duree visee d'une seance, en minutes", example = "60")
        @NotNull @Min(15) @Max(180) Integer sessionMinutes,

        @Schema(description = "Duree du programme en semaines", example = "8")
        @Min(1) @Max(52) Integer durationWeeks,

        @Schema(description = "Ou l'adherent s'entraine", example = "SALLE")
        @NotNull WorkoutLocation location,

        @Schema(description = """
                Materiel reellement disponible. Liste vide = tout le materiel de
                salle est considere comme accessible. Le poids de corps est
                toujours ajoute : il n'est jamais indisponible.""")
        List<Equipment> equipment,

        @Schema(description = "Jours de la semaine souhaites (1 = lundi ... 7 = dimanche)")
        List<@Min(1) @Max(7) Integer> preferredDays,

        @Schema(description = "Groupes musculaires a prioriser (points faibles, envies)")
        List<MuscleGroup> focusMuscles,

        @Schema(description = "Inclure du cardio dans le programme", example = "false")
        boolean includeCardio,

        // ── Charges de reference ─────────────────────────────────────
        //  Toutes optionnelles : un debutant ne les connait pas, et un
        //  programme reste utile sans. Quand elles sont la, les charges
        //  cibles cessent d'etre des cases vides.

        @Schema(description = "Charge maximale au developpe couche, en kg", example = "70")
        @Positive @Max(500) Double benchPressKg,

        @Schema(description = "Charge maximale au squat, en kg", example = "100")
        @Positive @Max(500) Double squatKg,

        @Schema(description = "Charge maximale au souleve de terre, en kg", example = "120")
        @Positive @Max(500) Double deadliftKg,

        @Schema(description = "Nombre de tractions strictes enchainees", example = "8")
        @PositiveOrZero @Max(100) Integer maxPullUps,

        @Schema(description = """
                Contraintes libres : douleurs, exercices a eviter, materiel
                manquant, contraintes d'horaire. C'est ici que remonte ce
                qu'aucune liste ne prevoit.""",
                example = "Genou droit fragile, pas de saut. Je n'ai que 30 minutes le vendredi.")
        @Size(max = 600) String constraints
) {

        /** Le materiel effectivement demande, poids de corps inclus. */
        public List<Equipment> equipmentOrEmpty() {
                return equipment == null ? List.of() : equipment;
        }

        public List<Integer> preferredDaysOrEmpty() {
                return preferredDays == null ? List.of() : preferredDays;
        }

        public List<MuscleGroup> focusMusclesOrEmpty() {
                return focusMuscles == null ? List.of() : focusMuscles;
        }
}
