package com.fitforge.api.training.service;

import com.fitforge.api.coaching.entity.CoachingRelationship;
import com.fitforge.api.coaching.repository.CoachingRelationshipRepository;
import com.fitforge.api.common.enums.CoachingStatus;
import com.fitforge.api.common.exception.BusinessException;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.training.dto.CreateProgramRequest;
import com.fitforge.api.training.dto.CreateSessionExerciseRequest;
import com.fitforge.api.training.dto.CreateSessionRequest;
import com.fitforge.api.training.dto.ProgramResponse;
import com.fitforge.api.training.entity.Exercise;
import com.fitforge.api.training.entity.SessionExercise;
import com.fitforge.api.training.entity.WorkoutProgram;
import com.fitforge.api.training.entity.WorkoutSession;
import com.fitforge.api.training.mapper.ProgramMapper;
import com.fitforge.api.training.repository.ExerciseRepository;
import com.fitforge.api.training.repository.SessionExerciseRepository;
import com.fitforge.api.training.repository.WorkoutProgramRepository;
import com.fitforge.api.training.repository.WorkoutSessionRepository;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * Logique metier des programmes d'entrainement, seances et exercices places.
 * Chaque operation sur une ressource personnelle verifie qu'elle appartient
 * bien a l'adherent connecte. Les modeles (programmes prets) sont partages et
 * accessibles a tous en lecture / adoption.
 */
@Service
@RequiredArgsConstructor
public class ProgramService {

    private final WorkoutProgramRepository programRepo;
    private final WorkoutSessionRepository sessionRepo;
    private final SessionExerciseRepository sessionExerciseRepo;
    private final ExerciseRepository exerciseRepo;
    private final UserRepository userRepo;
    private final CoachingRelationshipRepository relationshipRepo;
    private final ProgramMapper mapper;

    // ================================================================
    //  Programmes personnels
    // ================================================================

    /** Mes programmes. */
    @Transactional(readOnly = true)
    public List<ProgramResponse> getMyPrograms(UUID userId) {
        return programRepo.findByUserIdOrderByTitleAsc(userId).stream()
                .map(mapper::toResponse)
                .toList();
    }

    /** Detail d'un programme (avec seances + exercices). */
    @Transactional(readOnly = true)
    public ProgramResponse getProgram(UUID userId, UUID programId) {
        return mapper.toResponse(loadOwnedProgram(userId, programId));
    }

    /** Cree un programme rattache a l'adherent connecte. */
    @Transactional
    public ProgramResponse createProgram(UUID userId, CreateProgramRequest req) {
        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));

        WorkoutProgram program = WorkoutProgram.builder()
                .user(user)
                .title(req.title())
                .description(req.description())
                .goal(req.goal())
                .experienceLevel(req.experienceLevel())
                .durationWeeks(req.durationWeeks())
                // Un programme cree par un adherent n'est jamais un modele partage.
                .isTemplate(false)
                .build();

        return mapper.toResponse(programRepo.save(program));
    }

    /** Met a jour les infos d'un programme. */
    @Transactional
    public ProgramResponse updateProgram(UUID userId, UUID programId, CreateProgramRequest req) {
        WorkoutProgram program = loadOwnedProgram(userId, programId);
        program.setTitle(req.title());
        program.setDescription(req.description());
        program.setGoal(req.goal());
        program.setExperienceLevel(req.experienceLevel());
        program.setDurationWeeks(req.durationWeeks());
        return mapper.toResponse(programRepo.save(program));
    }

    /** Supprime un programme (et, en cascade, ses seances/exercices). */
    @Transactional
    public void deleteProgram(UUID userId, UUID programId) {
        WorkoutProgram program = loadOwnedProgram(userId, programId);
        programRepo.delete(program);
    }

    // ================================================================
    //  Programmes crees par un coach pour un adherent
    // ================================================================

    /**
     * Un coach compose un programme POUR l'un de ses adherents (suivi ACCEPTED).
     * Le programme est rattache a l'adherent (il apparaitra dans SA liste) et
     * porte le coach comme createur. Le coach pourra ensuite y ajouter seances
     * et exercices (il est autorise en tant que createur).
     */
    @Transactional
    public ProgramResponse createProgramForMember(UUID coachUserId, UUID memberUserId,
                                                  CreateProgramRequest req) {
        CoachingRelationship rel = relationshipRepo
                .findByCoachIdAndMemberId(coachUserId, memberUserId)
                .orElseThrow(() -> new BusinessException("Aucun suivi avec cet adherent"));
        if (rel.getStatus() != CoachingStatus.ACCEPTED) {
            throw new BusinessException("Le suivi doit etre actif pour creer un programme");
        }

        User member = userRepo.findById(memberUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Adherent introuvable"));
        User coach = userRepo.findById(coachUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));

        WorkoutProgram program = WorkoutProgram.builder()
                .user(member)
                .createdBy(coach)
                .title(req.title())
                .description(req.description())
                .goal(req.goal())
                .experienceLevel(req.experienceLevel())
                .durationWeeks(req.durationWeeks())
                .isTemplate(false)
                .build();

        return mapper.toResponse(programRepo.save(program));
    }

    /** Programmes qu'un coach a crees pour un adherent donne. */
    @Transactional(readOnly = true)
    public List<ProgramResponse> getProgramsCreatedForMember(UUID coachUserId, UUID memberUserId) {
        return programRepo
                .findByUserIdAndCreatedByIdOrderByTitleAsc(memberUserId, coachUserId)
                .stream()
                .map(mapper::toResponse)
                .toList();
    }

    // ================================================================
    //  Modeles (programmes prets a l'emploi)
    // ================================================================

    /** Liste des programmes modeles partages (Push/Pull/Legs, Full Body...). */
    @Transactional(readOnly = true)
    public List<ProgramResponse> getTemplates() {
        return programRepo.findTemplates().stream()
                .map(mapper::toResponse)
                .toList();
    }

    /** Detail d'un programme modele (avec seances + exercices). */
    @Transactional(readOnly = true)
    public ProgramResponse getTemplate(UUID templateId) {
        return mapper.toResponse(loadTemplate(templateId));
    }

    /**
     * "Adopte" un modele : en cree une copie personnelle (programme + seances +
     * exercices places) rattachee a l'adherent connecte, qu'il pourra ensuite
     * modifier librement. Le programme copie n'est plus un modele.
     */
    @Transactional
    public ProgramResponse adoptTemplate(UUID userId, UUID templateId) {
        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));
        WorkoutProgram template = loadTemplate(templateId);

        WorkoutProgram copy = WorkoutProgram.builder()
                .user(user)
                .title(template.getTitle())
                .description(template.getDescription())
                .goal(template.getGoal())
                .experienceLevel(template.getExperienceLevel())
                .durationWeeks(template.getDurationWeeks())
                .isTemplate(false)
                .build();

        // Copie profonde des seances et de leurs exercices places.
        for (WorkoutSession session : template.getSessions()) {
            WorkoutSession sessionCopy = WorkoutSession.builder()
                    .program(copy)
                    .title(session.getTitle())
                    .dayOfWeek(session.getDayOfWeek())
                    .orderIndex(session.getOrderIndex())
                    .build();

            for (SessionExercise se : session.getExercises()) {
                SessionExercise seCopy = SessionExercise.builder()
                        .session(sessionCopy)
                        .exercise(se.getExercise())
                        .targetSets(se.getTargetSets())
                        .targetReps(se.getTargetReps())
                        .targetWeightKg(se.getTargetWeightKg())
                        .restSeconds(se.getRestSeconds())
                        .notes(se.getNotes())
                        .orderIndex(se.getOrderIndex())
                        .build();
                sessionCopy.getExercises().add(seCopy);
            }
            copy.getSessions().add(sessionCopy);
        }

        return mapper.toResponse(programRepo.save(copy));
    }

    // ================================================================
    //  Seances
    // ================================================================

    /** Ajoute une seance a un programme. */
    @Transactional
    public ProgramResponse addSession(UUID userId, UUID programId, CreateSessionRequest req) {
        WorkoutProgram program = loadOwnedProgram(userId, programId);

        WorkoutSession session = WorkoutSession.builder()
                .program(program)
                .title(req.title())
                .dayOfWeek(req.dayOfWeek())
                // ordre par defaut : a la fin de la liste actuelle
                .orderIndex(req.orderIndex() != null ? req.orderIndex() : program.getSessions().size())
                .build();

        program.getSessions().add(session);   // cascade ALL -> insere la seance
        return mapper.toResponse(programRepo.save(program));
    }

    /** Met a jour une seance (titre, jour, ordre). */
    @Transactional
    public ProgramResponse updateSession(UUID userId, UUID sessionId, CreateSessionRequest req) {
        WorkoutSession session = loadOwnedSession(userId, sessionId);
        session.setTitle(req.title());
        session.setDayOfWeek(req.dayOfWeek());
        if (req.orderIndex() != null) {
            session.setOrderIndex(req.orderIndex());
        }
        sessionRepo.save(session);
        return mapper.toResponse(session.getProgram());
    }

    /** Supprime une seance (et, en cascade, ses exercices places). */
    @Transactional
    public ProgramResponse deleteSession(UUID userId, UUID sessionId) {
        WorkoutSession session = loadOwnedSession(userId, sessionId);
        WorkoutProgram program = session.getProgram();
        program.getSessions().remove(session);   // orphanRemoval -> supprime la seance
        programRepo.save(program);
        return mapper.toResponse(program);
    }

    // ================================================================
    //  Exercices places dans une seance
    // ================================================================

    /** Ajoute un exercice (du referentiel) a une seance, avec ses objectifs. */
    @Transactional
    public ProgramResponse addSessionExercise(UUID userId, UUID sessionId, CreateSessionExerciseRequest req) {
        WorkoutSession session = loadOwnedSession(userId, sessionId);

        Exercise exercise = exerciseRepo.findById(req.exerciseId())
                .orElseThrow(() -> new ResourceNotFoundException("Exercice introuvable"));

        SessionExercise se = SessionExercise.builder()
                .session(session)
                .exercise(exercise)
                .targetSets(req.targetSets())
                .targetReps(req.targetReps())
                .targetWeightKg(req.targetWeightKg())
                .restSeconds(req.restSeconds())
                .orderIndex(req.orderIndex() != null ? req.orderIndex() : session.getExercises().size())
                .build();

        session.getExercises().add(se);       // cascade ALL -> insere la ligne
        sessionRepo.save(session);

        // On renvoie le programme complet a jour
        return mapper.toResponse(session.getProgram());
    }

    /** Met a jour les objectifs d'un exercice place. */
    @Transactional
    public ProgramResponse updateSessionExercise(UUID userId, UUID sessionExerciseId,
                                                 CreateSessionExerciseRequest req) {
        SessionExercise se = loadOwnedSessionExercise(userId, sessionExerciseId);

        // L'exercice du referentiel peut etre remplace via exerciseId.
        if (req.exerciseId() != null && !req.exerciseId().equals(se.getExercise().getId())) {
            Exercise exercise = exerciseRepo.findById(req.exerciseId())
                    .orElseThrow(() -> new ResourceNotFoundException("Exercice introuvable"));
            se.setExercise(exercise);
        }
        se.setTargetSets(req.targetSets());
        se.setTargetReps(req.targetReps());
        se.setTargetWeightKg(req.targetWeightKg());
        se.setRestSeconds(req.restSeconds());
        if (req.orderIndex() != null) {
            se.setOrderIndex(req.orderIndex());
        }
        sessionExerciseRepo.save(se);
        return mapper.toResponse(se.getSession().getProgram());
    }

    /** Retire un exercice d'une seance. */
    @Transactional
    public ProgramResponse deleteSessionExercise(UUID userId, UUID sessionExerciseId) {
        SessionExercise se = loadOwnedSessionExercise(userId, sessionExerciseId);
        WorkoutSession session = se.getSession();
        session.getExercises().remove(se);    // orphanRemoval -> supprime la ligne
        sessionRepo.save(session);
        return mapper.toResponse(session.getProgram());
    }

    // ================================================================
    //  Helpers de chargement + controle de propriete (404 si non possede)
    // ================================================================

    /**
     * Charge un programme en verifiant qu'il appartient a l'adherent connecte.
     * Renvoie 404 si absent, s'il n'a pas de proprietaire (modele) ou s'il
     * appartient a quelqu'un d'autre (on ne revele pas l'existence de la
     * ressource d'un tiers).
     */
    private WorkoutProgram loadOwnedProgram(UUID userId, UUID programId) {
        WorkoutProgram program = programRepo.findById(programId)
                .orElseThrow(() -> new ResourceNotFoundException("Programme introuvable"));
        if (!canEdit(program, userId)) {
            throw new ResourceNotFoundException("Programme introuvable");
        }
        return program;
    }

    /**
     * Un programme est modifiable par son proprietaire (adherent) OU par son
     * createur (coach qui l'a compose pour lui). Les modeles (user/createur
     * null) ne sont modifiables par personne via ces routes.
     */
    private boolean canEdit(WorkoutProgram program, UUID userId) {
        if (program.getUser() != null && program.getUser().getId().equals(userId)) {
            return true;
        }
        return program.getCreatedBy() != null && program.getCreatedBy().getId().equals(userId);
    }

    /** Charge un modele partage (is_template = true, sans proprietaire). */
    private WorkoutProgram loadTemplate(UUID templateId) {
        WorkoutProgram program = programRepo.findById(templateId)
                .orElseThrow(() -> new ResourceNotFoundException("Modele introuvable"));
        if (!program.isTemplate() || program.getUser() != null) {
            throw new ResourceNotFoundException("Modele introuvable");
        }
        return program;
    }

    /** Charge une seance en verifiant que son programme appartient a l'adherent. */
    private WorkoutSession loadOwnedSession(UUID userId, UUID sessionId) {
        WorkoutSession session = sessionRepo.findById(sessionId)
                .orElseThrow(() -> new ResourceNotFoundException("Seance introuvable"));
        if (!canEdit(session.getProgram(), userId)) {
            throw new ResourceNotFoundException("Seance introuvable");
        }
        return session;
    }

    /** Charge un exercice place en verifiant la propriete via seance -> programme. */
    private SessionExercise loadOwnedSessionExercise(UUID userId, UUID sessionExerciseId) {
        SessionExercise se = sessionExerciseRepo.findById(sessionExerciseId)
                .orElseThrow(() -> new ResourceNotFoundException("Exercice de seance introuvable"));
        if (!canEdit(se.getSession().getProgram(), userId)) {
            throw new ResourceNotFoundException("Exercice de seance introuvable");
        }
        return se;
    }
}
