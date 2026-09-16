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

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Profil complet renvoye a Flutter. Contient les champs derives calcules par
 * le serveur (age, bmi, tdee) et des infos du compte (fullName, avatarUrl).
 */
@Schema(description = "Profil complet de l'adherent")
public record ProfileResponse(
        UUID id,
        String fullName,
        String avatarUrl,

        // Identite physique
        LocalDate birthDate,
        @Schema(description = "Age calcule cote serveur", example = "27") Integer age,
        Gender gender,
        Double heightCm,
        Double currentWeightKg,
        Double targetWeightKg,

        // Objectif & mode de vie
        FitnessGoal goal,
        ActivityLevel activityLevel,
        ExperienceLevel experienceLevel,
        Integer weeklyWorkoutTarget,
        WorkoutLocation preferredLocation,
        List<DayOfWeek> preferredWorkoutDays,
        List<Equipment> availableEquipment,

        // Sante
        List<String> injuries,
        String medicalNotes,

        // Nutrition & habitudes
        DietaryPreference dietaryPreference,
        List<String> allergies,
        Integer dailyCalorieTarget,
        Integer waterTargetMl,
        Double averageSleepHours,

        // Preferences applicatives
        UnitSystem unitSystem,
        String preferredLanguage,

        // Derives
        @Schema(description = "IMC calcule", example = "23.5") Double bmi,
        @Schema(description = "Depense energetique estimee (kcal/j)", example = "2450") Integer tdee,
        boolean onboardingCompleted
) {}
