package com.fitforge.api.training.service;

import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.training.dto.CreateSetLogRequest;
import com.fitforge.api.training.dto.CreateWorkoutLogRequest;
import com.fitforge.api.training.dto.LastPerformanceResponse;
import com.fitforge.api.training.dto.WorkoutLogResponse;
import com.fitforge.api.training.entity.Exercise;
import com.fitforge.api.training.entity.SetLog;
import com.fitforge.api.training.entity.WorkoutLog;
import com.fitforge.api.training.entity.WorkoutSession;
import com.fitforge.api.training.mapper.WorkoutLogMapper;
import com.fitforge.api.training.repository.ExerciseRepository;
import com.fitforge.api.training.repository.SetLogRepository;
import com.fitforge.api.training.repository.WorkoutLogRepository;
import com.fitforge.api.training.repository.WorkoutSessionRepository;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Logique metier des seances effectuees : enregistrement (avec series),
 * consultation par periode, detail et suppression.
 */
@Service
@RequiredArgsConstructor
public class WorkoutLogService {

    private final WorkoutLogRepository logRepo;
    private final WorkoutSessionRepository sessionRepo;
    private final ExerciseRepository exerciseRepo;
    private final SetLogRepository setLogRepo;
    private final UserRepository userRepo;
    private final WorkoutLogMapper mapper;

    /** Mes seances effectuees sur une periode. */
    @Transactional(readOnly = true)
    public List<WorkoutLogResponse> getMyLogs(UUID userId, LocalDate from, LocalDate to) {
        return logRepo.findByUserIdAndPerformedOnBetweenOrderByPerformedOnDesc(userId, from, to).stream()
                .map(mapper::toResponse)
                .toList();
    }

    /** Detail d'une seance effectuee (avec verification de propriete). */
    @Transactional(readOnly = true)
    public WorkoutLogResponse getLog(UUID userId, UUID logId) {
        return mapper.toResponse(loadOwnedLog(userId, logId));
    }

    /**
     * Ce que l'adherent a fait la derniere fois sur cet exercice.
     *
     * <p>Renvoie {@code null} s'il ne l'a jamais realise : l'ecran de saisie
     * affiche alors ses valeurs par defaut, sans bandeau. Un 404 serait un abus —
     * « jamais fait » n'est pas une erreur, c'est le cas normal du premier jour.
     */
    @Transactional(readOnly = true)
    public LastPerformanceResponse getLastPerformance(UUID userId, UUID exerciseId) {
        LocalDate day = setLogRepo.findLastPerformedOn(userId, exerciseId).orElse(null);
        if (day == null) {
            return null;
        }

        List<SetLog> sets = setLogRepo.findSetsOnDay(userId, exerciseId, day);
        if (sets.isEmpty()) {
            return null;
        }

        double volume = 0;
        Double best = null;
        List<LastPerformanceResponse.Set> items = new ArrayList<>(sets.size());
        for (SetLog s : sets) {
            int reps = s.getReps() != null ? s.getReps() : 0;
            double weight = s.getWeightKg() != null ? s.getWeightKg() : 0;
            volume += reps * weight;
            if (s.getWeightKg() != null && (best == null || s.getWeightKg() > best)) {
                best = s.getWeightKg();
            }
            items.add(new LastPerformanceResponse.Set(s.getSetNumber(), s.getReps(), s.getWeightKg()));
        }

        return new LastPerformanceResponse(
                day,
                ChronoUnit.DAYS.between(day, LocalDate.now()),
                items,
                best,
                volume);
    }

    /**
     * Enregistre une seance effectuee et ses series.
     * La seance-type (sessionId) est optionnelle. Chaque serie reference un
     * exercice du referentiel.
     */
    @Transactional
    public WorkoutLogResponse createLog(UUID userId, CreateWorkoutLogRequest req) {
        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));

        // Seance-type optionnelle : on la charge seulement si un id est fourni
        WorkoutSession session = null;
        if (req.sessionId() != null) {
            session = sessionRepo.findById(req.sessionId())
                    .orElseThrow(() -> new ResourceNotFoundException("Seance introuvable"));
        }

        WorkoutLog log = WorkoutLog.builder()
                .user(user)
                .session(session)
                .performedOn(req.performedOn())
                .durationMinutes(req.durationMinutes())
                .rpe(req.rpe())
                .build();

        // Ajout des series : chaque serie est rattachee au log (cascade ALL a l'insert)
        if (req.sets() != null) {
            for (CreateSetLogRequest s : req.sets()) {
                Exercise exercise = exerciseRepo.findById(s.exerciseId())
                        .orElseThrow(() -> new ResourceNotFoundException(
                                "Exercice introuvable : " + s.exerciseId()));
                SetLog set = SetLog.builder()
                        .workoutLog(log)
                        .exercise(exercise)
                        .setNumber(s.setNumber())
                        .reps(s.reps())
                        .weightKg(s.weightKg())
                        .completed(s.completed())
                        .build();
                log.getSets().add(set);
            }
        }

        return mapper.toResponse(logRepo.save(log));
    }

    /** Supprime une seance effectuee (et ses series en cascade). */
    @Transactional
    public void deleteLog(UUID userId, UUID logId) {
        WorkoutLog log = loadOwnedLog(userId, logId);
        logRepo.delete(log);
    }

    /** Charge un log en verifiant qu'il appartient a l'adherent connecte. */
    private WorkoutLog loadOwnedLog(UUID userId, UUID logId) {
        WorkoutLog log = logRepo.findById(logId)
                .orElseThrow(() -> new ResourceNotFoundException("Seance introuvable"));
        if (!log.getUser().getId().equals(userId)) {
            throw new ResourceNotFoundException("Seance introuvable");
        }
        return log;
    }
}
