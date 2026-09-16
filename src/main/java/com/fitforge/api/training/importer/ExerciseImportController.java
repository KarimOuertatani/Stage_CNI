package com.fitforge.api.training.importer;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Endpoint d'administration pour declencher l'import ExerciseDB a la demande.
 *
 * <p>Protege par role (ADMIN ou COACH) dans {@code SecurityConfig} via le
 * chemin {@code /api/v1/admin/**}. A n'utiliser qu'une fois pour peupler la
 * base : l'operation enchaine des centaines d'appels a l'API externe.
 */
@RestController
@RequestMapping("/api/v1/admin/exercises")
@RequiredArgsConstructor
@Tag(name = "Admin - Import exercices",
        description = "Import du referentiel ExerciseDB (reserve ADMIN/COACH)")
public class ExerciseImportController {

    private final ExerciseImportService importService;

    @PostMapping("/import")
    @Operation(summary = "Importer les exercices depuis ExerciseDB V2 (max 200 sur le plan gratuit)")
    public Map<String, Object> triggerImport(
            @RequestParam(name = "max", defaultValue = "200") int max) {
        int count = importService.importAll(max);
        return Map.of(
                "imported", count,
                "message", "Import termine : " + count + " exercice(s) ajoute(s).");
    }

    @PostMapping("/enrich")
    @Operation(summary = "Doter les exercices seed (sans video) du media d'un exercice importe equivalent")
    public Map<String, Object> triggerEnrich() {
        int count = importService.enrichSeedExercises();
        return Map.of(
                "enriched", count,
                "message", "Enrichissement termine : " + count + " exercice(s) dote(s) d'une video.");
    }
}
