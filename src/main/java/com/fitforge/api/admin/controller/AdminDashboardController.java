package com.fitforge.api.admin.controller;

import com.fitforge.api.admin.dto.AdminDashboardResponse;
import com.fitforge.api.admin.dto.AiHealthResponse;
import com.fitforge.api.admin.service.AdminAiHealthService;
import com.fitforge.api.admin.service.AdminDashboardService;
import com.fitforge.api.admin.service.GeminiProbeClient;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Tableau de bord et supervision de l'IA (role ADMIN). */
@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
@Tag(name = "Admin - Tableau de bord", description = "Statistiques et sante de l'IA (role ADMIN)")
public class AdminDashboardController {

    private final AdminDashboardService dashboardService;
    private final AdminAiHealthService aiHealthService;

    @GetMapping("/dashboard")
    @Operation(summary = "Tableau de bord : ce qui attend une action, les comptes, l'activite")
    public AdminDashboardResponse dashboard() {
        return dashboardService.dashboard();
    }

    @GetMapping("/ai-health")
    @Operation(summary = "Sante des fonctions IA : taux d'echec, latence et dernieres erreurs")
    public AiHealthResponse aiHealth() {
        return aiHealthService.health();
    }

    /**
     * Sonde en direct.
     *
     * <p>{@code POST} et non {@code GET}, bien que rien ne soit cree : l'appel
     * a un effet de bord reel -- il consomme le quota Gemini partage par toutes
     * les fonctions et ecrit une ligne de journal. Une route {@code GET} peut
     * etre rejouee par un navigateur, prechargee, ou relancee a chaque
     * rafraichissement de la page ; le verbe dit ici que le declenchement doit
     * rester un geste explicite.
     */
    @PostMapping("/ai-health/probe")
    @Operation(summary = "Appeler reellement le modele pour verifier qu'il repond maintenant")
    public GeminiProbeClient.ProbeResult probe() {
        return aiHealthService.probe();
    }
}
