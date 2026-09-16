package com.fitforge.api.user.controller;

import com.fitforge.api.security.UserPrincipal;
import com.fitforge.api.user.dto.CreateMeasurementRequest;
import com.fitforge.api.user.dto.MeasurementResponse;
import com.fitforge.api.user.service.MeasurementService;
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
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * API de l'historique des mensurations (courbe de poids cote Flutter).
 */
@RestController
@RequestMapping("/api/v1/measurements")
@RequiredArgsConstructor
@Tag(name = "Mensurations", description = "Historique poids/mensurations de l'adherent")
public class MeasurementController {

    private final MeasurementService service;

    @GetMapping
    @Operation(summary = "Historique de mes pesees/mensurations (recentes d'abord)")
    public List<MeasurementResponse> getMyMeasurements(@AuthenticationPrincipal UserPrincipal me) {
        return service.getMyMeasurements(me.getId());
    }

    @PostMapping
    @Operation(summary = "Ajouter une pesee")
    public ResponseEntity<MeasurementResponse> add(
            @AuthenticationPrincipal UserPrincipal me,
            @Valid @RequestBody CreateMeasurementRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.addMeasurement(me.getId(), req));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Supprimer une pesee")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id) {
        service.deleteMeasurement(me.getId(), id);
        return ResponseEntity.noContent().build();   // 204
    }
}
