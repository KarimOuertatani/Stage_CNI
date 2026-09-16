package com.fitforge.api.admin.dto;

import com.fitforge.api.common.enums.CoachStatus;
import com.fitforge.api.common.enums.FitnessGoal;
import com.fitforge.api.common.enums.Gender;
import com.fitforge.api.common.enums.Role;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Fiche complete d'un membre, vue par l'administration.
 *
 * <h2>Ce que cette fiche ne contient PAS, et pourquoi</h2>
 * Ni le contenu des conversations, ni le detail des repas, ni les notes
 * medicales libres du profil. L'administration a besoin de savoir <b>si</b> un
 * compte est actif et <b>a quel point</b>, pas de lire ce que la personne
 * ecrit. Les compteurs ci-dessous repondent a la premiere question sans jamais
 * ouvrir la seconde.
 *
 * <p>C'est le meme raisonnement que pour le coach IA, qui envoie l'objectif et
 * le niveau au modele mais jamais le nom ni les notes medicales : on transmet
 * ce qui sert, pas ce qui est disponible.
 */
@Schema(description = "Fiche d'un membre, vue administrateur")
public record AdminUserDetail(

        // ── Compte ───────────────────────────────────────────────
        UUID id,
        String fullName,
        String email,
        String phoneNumber,
        String avatarUrl,
        Role role,
        boolean enabled,
        boolean emailVerified,
        Instant createdAt,
        Instant lastLoginAt,
        Instant lastSeenAt,

        // ── Profil sportif (adherent) ────────────────────────────
        Gender gender,
        LocalDate birthDate,
        Integer age,
        Double heightCm,
        Double currentWeightKg,
        FitnessGoal goal,
        boolean onboardingCompleted,

        // ── Coach ────────────────────────────────────────────────
        @Schema(description = "Renseigne uniquement si le compte est un coach")
        CoachStatus coachStatus,
        UUID coachProfileId,

        // ── Activite (compteurs, jamais de contenu) ──────────────
        long workoutLogCount,
        LocalDate lastWorkoutDate,
        long nutritionEntryCount,
        long sleepEntryCount,
        long programCount
) {}
