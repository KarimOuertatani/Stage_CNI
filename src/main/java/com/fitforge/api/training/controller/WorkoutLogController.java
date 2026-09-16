package com.fitforge.api.training.controller;

import com.fitforge.api.security.UserPrincipal;
import com.fitforge.api.training.dto.CreateWorkoutLogRequest;
import com.fitforge.api.training.dto.LastPerformanceResponse;
import com.fitforge.api.training.dto.WorkoutLogResponse;
import com.fitforge.api.training.service.WorkoutLogService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * API des seances effectuees (tracking de l'entrainement).
 */
@RestController
@RequestMapping("/api/v1/workout-logs")
@RequiredArgsConstructor
@Tag(name = "Logs d'entrainement", description = "Seances reellement effectuees et leurs series")
public class WorkoutLogController {

    private final WorkoutLogService service;

    @GetMapping
    @Operation(summary = "Mes seances effectuees sur une periode [from, to]")
    public List<WorkoutLogResponse> myLogs(
            @AuthenticationPrincipal UserPrincipal me,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return service.getMyLogs(me.getId(), from, to);
    }

    @PostMapping
    @Operation(summary = "Enregistrer une seance effectuee (+ ses series)")
    public ResponseEntity<WorkoutLogResponse> create(
            @AuthenticationPrincipal UserPrincipal me,
            @Valid @RequestBody CreateWorkoutLogRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.createLog(me.getId(), req));
    }

    /**
     * Doit rester DECLARE AVANT {@code /{id}} : sinon Spring tenterait de
     * convertir le segment « last » en UUID et renverrait une 400.
     */
    @GetMapping("/last")
    @Operation(summary = "Ma derniere performance sur un exercice (204 si jamais realise)")
    public ResponseEntity<LastPerformanceResponse> lastPerformance(
            @AuthenticationPrincipal UserPrincipal me,
            @RequestParam UUID exerciseId) {
        LastPerformanceResponse last = service.getLastPerformance(me.getId(), exerciseId);
        // 204 et non 404 : « jamais realise » est le cas normal du premier jour,
        // pas une ressource manquante. Le client n'a alors rien a afficher.
        return last == null ? ResponseEntity.noContent().build() : ResponseEntity.ok(last);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Detail d'une seance effectuee")
    public WorkoutLogResponse getOne(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id) {
        return service.getLog(me.getId(), id);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Supprimer une seance effectuee")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id) {
        service.deleteLog(me.getId(), id);
        return ResponseEntity.noContent().build();
    }
}
