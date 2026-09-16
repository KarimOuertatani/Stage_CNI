package com.fitforge.api.score.service;

import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.score.dto.TrainingScoreResponse;
import com.fitforge.api.score.entity.TrainingScore;
import com.fitforge.api.score.mapper.TrainingScoreMapper;
import com.fitforge.api.score.repository.TrainingScoreRepository;
import com.fitforge.api.training.entity.SetLog;
import com.fitforge.api.training.entity.WorkoutLog;
import com.fitforge.api.training.repository.WorkoutLogRepository;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.entity.UserProfile;
import com.fitforge.api.user.repository.UserProfileRepository;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import java.util.UUID;

/**
 * Calcul et consultation du score d'entrainement.
 *
 * Principe du score (note 0..100) sur une semaine (lundi -> dimanche) :
 *  - assiduite (consistency) : nb de seances faites / objectif hebdo du profil.
 *    Compte pour 70 points maximum.
 *  - progression du volume : volume souleve compare a la semaine precedente.
 *    Compte pour 30 points maximum.
 * Un "insight" (phrase d'analyse) resume le resultat pour l'affichage Flutter.
 */
@Service
@RequiredArgsConstructor
public class TrainingScoreService {

    /** Objectif hebdo par defaut si le profil n'en precise pas. */
    private static final int DEFAULT_WEEKLY_TARGET = 3;

    private final TrainingScoreRepository scoreRepo;
    private final WorkoutLogRepository logRepo;
    private final UserProfileRepository profileRepo;
    private final UserRepository userRepo;
    private final TrainingScoreMapper mapper;

    /** Mon score le plus recent. */
    @Transactional(readOnly = true)
    public TrainingScoreResponse getCurrent(UUID userId) {
        return scoreRepo.findTopByUserIdOrderByScoreDateDesc(userId)
                .map(mapper::toResponse)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Aucun score calcule. Lance un recalcul apres une seance."));
    }

    /** Historique des N dernieres semaines de score. */
    @Transactional(readOnly = true)
    public List<TrainingScoreResponse> getHistory(UUID userId, int weeks) {
        return scoreRepo.findByUserIdOrderByScoreDateDesc(userId, PageRequest.of(0, weeks)).stream()
                .map(mapper::toResponse)
                .toList();
    }

    /**
     * Recalcule le score de la semaine courante et l'enregistre (un seul score
     * par semaine : on met a jour la ligne existante si elle existe).
     * Declenche typiquement apres l'enregistrement d'une seance.
     */
    @Transactional
    public TrainingScoreResponse recompute(UUID userId) {
        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));

        // --- Bornes de la semaine courante (lundi -> dimanche) ---
        LocalDate today = LocalDate.now();
        LocalDate weekStart = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
        LocalDate weekEnd = weekStart.plusDays(6);
        LocalDate prevStart = weekStart.minusWeeks(1);
        LocalDate prevEnd = weekStart.minusDays(1);

        // --- Donnees de la semaine courante et de la precedente ---
        List<WorkoutLog> currentLogs = logRepo
                .findByUserIdAndPerformedOnBetweenOrderByPerformedOnDesc(userId, weekStart, weekEnd);
        List<WorkoutLog> previousLogs = logRepo
                .findByUserIdAndPerformedOnBetweenOrderByPerformedOnDesc(userId, prevStart, prevEnd);

        int sessionsCompleted = currentLogs.size();
        double currentVolume = totalVolume(currentLogs);
        double previousVolume = totalVolume(previousLogs);

        // --- Assiduite : seances faites / objectif hebdo (plafonnee a 1.0) ---
        int weeklyTarget = resolveWeeklyTarget(userId);
        double consistencyRate = Math.min(1.0, (double) sessionsCompleted / weeklyTarget);

        // --- Composante assiduite : jusqu'a 70 points ---
        double consistencyPoints = consistencyRate * 70.0;

        // --- Composante progression du volume : jusqu'a 30 points ---
        double progressionPoints;
        Double progressionPercent = null;   // null = pas de reference (1ere semaine)
        if (previousVolume > 0) {
            double progression = (currentVolume - previousVolume) / previousVolume; // ex : +0.08
            progressionPercent = progression * 100.0;
            // 15 points de base pour avoir maintenu le volume, +/- selon la progression
            progressionPoints = clamp(15.0 + progression * 100.0 * 0.3, 0.0, 30.0);
        } else {
            // Pas de semaine precedente : bonus si on a souleve quelque chose
            progressionPoints = currentVolume > 0 ? 15.0 : 0.0;
        }

        int score = (int) Math.round(clamp(consistencyPoints + progressionPoints, 0.0, 100.0));

        String insight = buildInsight(sessionsCompleted, weeklyTarget, progressionPercent, currentVolume);

        // --- Upsert : une seule ligne de score par semaine ---
        TrainingScore entity = scoreRepo.findByUserIdAndScoreDate(userId, weekStart)
                .orElseGet(() -> TrainingScore.builder().user(user).scoreDate(weekStart).build());
        entity.setScore(score);
        entity.setWeeklyVolumeKg(round(currentVolume, 1));
        entity.setSessionsCompleted(sessionsCompleted);
        entity.setConsistencyRate(round(consistencyRate, 2));
        entity.setInsight(insight);

        return mapper.toResponse(scoreRepo.save(entity));
    }

    /** Somme du volume (Σ reps * poids) sur toutes les series de toutes les seances. */
    private double totalVolume(List<WorkoutLog> logs) {
        double volume = 0;
        for (WorkoutLog log : logs) {
            for (SetLog set : log.getSets()) {
                if (set.getReps() != null && set.getWeightKg() != null) {
                    volume += set.getReps() * set.getWeightKg();
                }
            }
        }
        return volume;
    }

    /** Objectif hebdo du profil, ou valeur par defaut si absent/invalide. */
    private int resolveWeeklyTarget(UUID userId) {
        return profileRepo.findByUserId(userId)
                .map(UserProfile::getWeeklyWorkoutTarget)
                .filter(t -> t != null && t > 0)
                .orElse(DEFAULT_WEEKLY_TARGET);
    }

    /** Construit la phrase d'analyse affichee dans l'app. */
    private String buildInsight(int sessions, int target, Double progressionPercent, double volume) {
        StringBuilder sb = new StringBuilder();

        if (progressionPercent == null) {
            sb.append("Premiere semaine enregistree. ");
        } else if (progressionPercent >= 1) {
            sb.append(String.format("Volume en hausse de %.0f%%. ", progressionPercent));
        } else if (progressionPercent <= -1) {
            sb.append(String.format("Volume en baisse de %.0f%%. ", Math.abs(progressionPercent)));
        } else {
            sb.append("Volume stable. ");
        }

        if (sessions >= target) {
            sb.append("Objectif hebdo atteint, bravo !");
        } else if (sessions == 0) {
            sb.append("Aucune seance cette semaine, on s'y remet !");
        } else {
            sb.append(String.format("%d/%d seances, encore un effort.", sessions, target));
        }
        return sb.toString();
    }

    private double clamp(double value, double min, double max) {
        return Math.max(min, Math.min(max, value));
    }

    private double round(double value, int decimals) {
        return BigDecimal.valueOf(value).setScale(decimals, RoundingMode.HALF_UP).doubleValue();
    }
}
