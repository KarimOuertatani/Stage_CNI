package com.fitforge.api.training.controller;

import com.fitforge.api.security.UserPrincipal;
import com.fitforge.api.training.dto.CreateProgramRequest;
import com.fitforge.api.training.dto.CreateSessionExerciseRequest;
import com.fitforge.api.training.dto.CreateSessionRequest;
import com.fitforge.api.training.dto.ProgramResponse;
import com.fitforge.api.training.service.ProgramService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * API des programmes d'entrainement, de leurs seances et des exercices places.
 * Base /api/v1 : les programmes sont sous /programs, l'ajout d'exercice a une
 * seance est sous /sessions/{id}/exercises (conforme a la liste d'endpoints).
 */
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
@Tag(name = "Programmes", description = "Programmes, seances et exercices places")
public class ProgramController {

    private final ProgramService service;

    @GetMapping("/programs")
    @Operation(summary = "Mes programmes")
    public List<ProgramResponse> myPrograms(@AuthenticationPrincipal UserPrincipal me) {
        return service.getMyPrograms(me.getId());
    }

    // ── Modeles (programmes prets a l'emploi) ─────────────────────────

    @GetMapping("/programs/templates")
    @Operation(summary = "Programmes prets a l'emploi (modeles partages)")
    public List<ProgramResponse> templates() {
        return service.getTemplates();
    }

    @GetMapping("/programs/templates/{id}")
    @Operation(summary = "Detail d'un programme modele")
    public ProgramResponse getTemplate(@PathVariable UUID id) {
        return service.getTemplate(id);
    }

    @PostMapping("/programs/templates/{id}/adopt")
    @Operation(summary = "Adopter un modele (copie personnelle modifiable)")
    public ResponseEntity<ProgramResponse> adopt(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(service.adoptTemplate(me.getId(), id));
    }

    @PostMapping("/programs")
    @Operation(summary = "Creer un programme")
    public ResponseEntity<ProgramResponse> create(
            @AuthenticationPrincipal UserPrincipal me,
            @Valid @RequestBody CreateProgramRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.createProgram(me.getId(), req));
    }

    // ── Coach : programmes composes pour un adherent ──────────────────

    @PostMapping("/programs/for-member/{memberUserId}")
    @Operation(summary = "Coach : creer un programme pour un adherent suivi")
    public ResponseEntity<ProgramResponse> createForMember(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID memberUserId,
            @Valid @RequestBody CreateProgramRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(service.createProgramForMember(me.getId(), memberUserId, req));
    }

    @GetMapping("/programs/for-member/{memberUserId}")
    @Operation(summary = "Coach : programmes crees pour un adherent")
    public List<ProgramResponse> forMember(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID memberUserId) {
        return service.getProgramsCreatedForMember(me.getId(), memberUserId);
    }

    @GetMapping("/programs/{id}")
    @Operation(summary = "Detail d'un programme (avec seances + exercices)")
    public ProgramResponse getOne(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id) {
        return service.getProgram(me.getId(), id);
    }

    @PutMapping("/programs/{id}")
    @Operation(summary = "Modifier un programme")
    public ProgramResponse update(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id,
            @Valid @RequestBody CreateProgramRequest req) {
        return service.updateProgram(me.getId(), id, req);
    }

    @DeleteMapping("/programs/{id}")
    @Operation(summary = "Supprimer un programme")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id) {
        service.deleteProgram(me.getId(), id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/programs/{id}/sessions")
    @Operation(summary = "Ajouter une seance a un programme")
    public ResponseEntity<ProgramResponse> addSession(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id,
            @Valid @RequestBody CreateSessionRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.addSession(me.getId(), id, req));
    }

    @PutMapping("/sessions/{id}")
    @Operation(summary = "Modifier une seance")
    public ProgramResponse updateSession(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id,
            @Valid @RequestBody CreateSessionRequest req) {
        return service.updateSession(me.getId(), id, req);
    }

    @DeleteMapping("/sessions/{id}")
    @Operation(summary = "Supprimer une seance")
    public ProgramResponse deleteSession(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id) {
        return service.deleteSession(me.getId(), id);
    }

    @PostMapping("/sessions/{id}/exercises")
    @Operation(summary = "Ajouter un exercice a une seance")
    public ResponseEntity<ProgramResponse> addSessionExercise(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id,
            @Valid @RequestBody CreateSessionExerciseRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.addSessionExercise(me.getId(), id, req));
    }

    @PutMapping("/session-exercises/{id}")
    @Operation(summary = "Modifier un exercice place (objectifs)")
    public ProgramResponse updateSessionExercise(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id,
            @Valid @RequestBody CreateSessionExerciseRequest req) {
        return service.updateSessionExercise(me.getId(), id, req);
    }

    @DeleteMapping("/session-exercises/{id}")
    @Operation(summary = "Retirer un exercice d'une seance")
    public ProgramResponse deleteSessionExercise(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id) {
        return service.deleteSessionExercise(me.getId(), id);
    }
}
