package com.fitforge.api.admin.controller;

import com.fitforge.api.admin.dto.CreateProblemReportRequest;
import com.fitforge.api.admin.dto.ProblemReportResponse;
import com.fitforge.api.admin.service.ProblemReportService;
import com.fitforge.api.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Signalement d'un probleme, cote utilisateur.
 *
 * <h2>Pourquoi ces routes ne sont PAS sous {@code /admin}</h2>
 * Elles sont ouvertes a <b>tout compte authentifie</b> -- adherent comme coach.
 * Les placer sous le prefixe d'administration les aurait rendues inaccessibles
 * a ceux qui en ont l'usage. Le service, lui, est partage avec la console :
 * meme table, deux niveaux de detail.
 *
 * <p>Aucune de ces routes ne prend d'identifiant d'utilisateur : on ne peut
 * signaler qu'en son nom, et ne consulter que ses propres signalements.
 */
@RestController
@RequestMapping("/api/v1/problem-reports")
@RequiredArgsConstructor
@Tag(name = "Signalements", description = "Signaler un probleme et suivre son traitement")
public class ProblemReportController {

    private final ProblemReportService service;

    @PostMapping
    @Operation(summary = "Signaler un probleme")
    public ResponseEntity<ProblemReportResponse> create(
            @AuthenticationPrincipal UserPrincipal me,
            @Valid @RequestBody CreateProblemReportRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(me.getId(), request));
    }

    @GetMapping
    @Operation(summary = "Mes signalements, avec leur statut et la reponse de l'equipe")
    public List<ProblemReportResponse> myReports(@AuthenticationPrincipal UserPrincipal me) {
        return service.myReports(me.getId());
    }
}
