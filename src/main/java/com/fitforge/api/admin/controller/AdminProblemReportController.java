package com.fitforge.api.admin.controller;

import com.fitforge.api.admin.dto.AdminProblemReportResponse;
import com.fitforge.api.admin.dto.HandleProblemReportRequest;
import com.fitforge.api.admin.service.ProblemReportService;
import com.fitforge.api.common.dto.PageResponse;
import com.fitforge.api.common.enums.ProblemStatus;
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

/** Traitement des signalements depuis la console (role ADMIN). */
@RestController
@RequestMapping("/api/v1/admin/problem-reports")
@RequiredArgsConstructor
@Tag(name = "Admin - Signalements", description = "File des signalements et traitement (role ADMIN)")
public class AdminProblemReportController {

    private final ProblemReportService service;

    @GetMapping
    @Operation(summary = "File des signalements, filtrable par statut")
    public PageResponse<AdminProblemReportResponse> list(
            @RequestParam(required = false) ProblemStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return service.list(status, page, size);
    }

    @GetMapping("/counts")
    @Operation(summary = "Nombre de signalements par statut")
    public Map<String, Long> counts() {
        return service.countsByStatus();
    }

    @GetMapping("/{reportId}")
    @Operation(summary = "Detail d'un signalement, avec son auteur et le contexte technique")
    public AdminProblemReportResponse detail(@PathVariable UUID reportId) {
        return service.detail(reportId);
    }

    @PostMapping("/{reportId}/handle")
    @Operation(summary = "Changer le statut et repondre a l'auteur (reponse obligatoire pour cloturer)")
    public AdminProblemReportResponse handle(
            @AuthenticationPrincipal UserPrincipal admin,
            @PathVariable UUID reportId,
            @Valid @RequestBody HandleProblemReportRequest request) {
        return service.handle(admin.getId(), reportId, request.status(), request.response());
    }
}
