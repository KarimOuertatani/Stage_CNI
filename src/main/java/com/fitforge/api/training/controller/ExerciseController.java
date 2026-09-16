package com.fitforge.api.training.controller;

import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.common.enums.ExperienceLevel;
import com.fitforge.api.common.enums.MuscleGroup;
import com.fitforge.api.security.UserPrincipal;
import com.fitforge.api.training.dto.ExerciseResponse;
import com.fitforge.api.training.service.ExerciseService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * API du referentiel d'exercices (consultation par l'adherent) et de ses favoris.
 */
@RestController
@RequestMapping("/api/v1/exercises")
@RequiredArgsConstructor
@Tag(name = "Exercices", description = "Referentiel d'exercices (catalogue)")
public class ExerciseController {

    private final ExerciseService service;

    @GetMapping
    @Operation(summary = "Lister / filtrer les exercices (muscle, materiel, zone, niveau, texte libre)")
    public List<ExerciseResponse> list(
            @RequestParam(required = false) MuscleGroup muscle,
            @RequestParam(required = false) Equipment equipment,
            @RequestParam(required = false) String bodyPart,
            @RequestParam(required = false) ExperienceLevel level,
            @RequestParam(required = false) String q) {
        return service.search(muscle, equipment, bodyPart, level, q);
    }

    /**
     * Doit rester DECLARE AVANT {@code /{id}} : sans cela, Spring tenterait de
     * convertir le segment « favorites » en UUID et renverrait une 400.
     */
    @GetMapping("/favorites")
    @Operation(summary = "Mes exercices favoris (le dernier ajoute en tete)")
    public List<ExerciseResponse> favorites(@AuthenticationPrincipal UserPrincipal me) {
        return service.getFavorites(me.getId());
    }

    @GetMapping("/{id}")
    @Operation(summary = "Detail d'un exercice")
    public ExerciseResponse getOne(@PathVariable UUID id) {
        return service.getById(id);
    }

    /** PUT et non POST : l'operation est idempotente (voir ExerciseService). */
    @PutMapping("/{id}/favorite")
    @Operation(summary = "Ajouter un exercice a mes favoris")
    public ResponseEntity<Void> addFavorite(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id) {
        service.addFavorite(me.getId(), id);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{id}/favorite")
    @Operation(summary = "Retirer un exercice de mes favoris")
    public ResponseEntity<Void> removeFavorite(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id) {
        service.removeFavorite(me.getId(), id);
        return ResponseEntity.noContent().build();
    }
}
