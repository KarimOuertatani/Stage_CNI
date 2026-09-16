package com.fitforge.api.user.dto;

import com.fitforge.api.common.enums.ActivityLevel;
import com.fitforge.api.common.enums.DietaryPreference;
import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.common.enums.ExperienceLevel;
import com.fitforge.api.common.enums.FitnessGoal;
import com.fitforge.api.common.enums.Gender;
import com.fitforge.api.common.enums.UnitSystem;
import com.fitforge.api.common.enums.WorkoutLocation;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.List;

/**
 * Donnees envoyees par Flutter pour creer/mettre a jour le profil de l'adherent.
 * On ne demande jamais l'age : c'est la date de naissance qui est fournie,
 * l'age (et l'IMC, le TDEE) sont recalcules cote serveur.
 */
@Schema(description = "Requete de creation/mise a jour du profil adherent")
public record UpdateProfileRequest(

        // --- Identite physique ---
        @Schema(description = "Date de naissance", example = "1998-05-12")
        @Past LocalDate birthDate,
        Gender gender,
        @Schema(example = "178.0") @Positive Double heightCm,
        @Schema(example = "74.5") @Positive Double currentWeightKg,
        @Schema(example = "70.0") @Positive Double targetWeightKg,

        // --- Objectif & mode de vie ---
        FitnessGoal goal,
        ActivityLevel activityLevel,
        ExperienceLevel experienceLevel,
        @Schema(example = "4") @Min(0) @Max(14) Integer weeklyWorkoutTarget,
        WorkoutLocation preferredLocation,
        List<DayOfWeek> preferredWorkoutDays,
        List<Equipment> availableEquipment,

        // --- Sante ---
        List<String> injuries,
        String medicalNotes,

        // --- Nutrition & habitudes ---
        DietaryPreference dietaryPreference,
        List<String> allergies,
        @Positive Integer dailyCalorieTarget,
        @Positive Integer waterTargetMl,
        @PositiveOrZero Double averageSleepHours,

        // --- Preferences applicatives ---
        UnitSystem unitSystem,
        @Schema(example = "fr") String preferredLanguage
) {}
