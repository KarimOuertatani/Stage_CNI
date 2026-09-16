package com.fitforge.api.admin.controller;

import com.fitforge.api.admin.dto.AdminCoachApplicationDetail;
import com.fitforge.api.admin.dto.AdminCoachApplicationSummary;
import com.fitforge.api.admin.dto.ReviewDecisionRequest;
import com.fitforge.api.admin.service.AdminCoachApplicationService;
import com.fitforge.api.common.dto.PageResponse;
import com.fitforge.api.common.enums.CoachStatus;
import com.fitforge.api.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.UUID;

/**
 * Examen des candidatures de coach, reserve a l'administration.
 *
 * <p><b>Le prefixe est ce qui protege ces routes.</b> Tout ce qui vit sous
 * {@code /api/v1/admin/**} (a l'exception documentee de l'import ExerciseDB)
 * exige le role ADMIN, declare une seule fois dans {@code SecurityConfig}.
 * Aucun controle de role n'est donc repete ici : le dupliquer donnerait deux
 * endroits ou se tromper, et l'oubli serait invisible.
 */
@RestController
@RequestMapping("/api/v1/admin/coach-applications")
@RequiredArgsConstructor
@Tag(name = "Admin - Candidatures coach",
        description = "File d'attente, examen des dossiers et decisions (role ADMIN)")
public class AdminCoachApplicationController {

    private final AdminCoachApplicationService service;

    @GetMapping
    @Operation(summary = "File des candidatures, filtrable par statut")
    public PageResponse<AdminCoachApplicationSummary> list(
            @RequestParam(required = false) CoachStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return service.list(status, page, size);
    }

    @GetMapping("/counts")
    @Operation(summary = "Nombre de dossiers par statut (pastilles de la console)")
    public Map<String, Long> counts() {
        return service.countsByStatus();
    }

    @GetMapping("/{profileId}")
    @Operation(summary = "Dossier complet : profil declare, titres revendiques, justificatifs")
    public AdminCoachApplicationDetail detail(@PathVariable UUID profileId) {
        return service.detail(profileId);
    }

    @PostMapping("/{profileId}/approve")
    @Operation(summary = "Valider le dossier : le coach entre dans l'annuaire (email envoye)")
    public AdminCoachApplicationDetail approve(
            @AuthenticationPrincipal UserPrincipal admin,
            @PathVariable UUID profileId) {
        return service.approve(admin.getId(), profileId);
    }

    @PostMapping("/{profileId}/reject")
    @Operation(summary = "Refuser le dossier avec un motif (email envoye, correction possible)")
    public AdminCoachApplicationDetail reject(
            @AuthenticationPrincipal UserPrincipal admin,
            @PathVariable UUID profileId,
            @Valid @RequestBody ReviewDecisionRequest request) {
        return service.reject(admin.getId(), profileId, request.reason());
    }

    @PostMapping("/{profileId}/suspend")
    @Operation(summary = "Suspendre un coach deja valide (retrait de l'annuaire, suivis conserves)")
    public AdminCoachApplicationDetail suspend(
            @AuthenticationPrincipal UserPrincipal admin,
            @PathVariable UUID profileId,
            @Valid @RequestBody ReviewDecisionRequest request) {
        return service.suspend(admin.getId(), profileId, request.reason());
    }
}
