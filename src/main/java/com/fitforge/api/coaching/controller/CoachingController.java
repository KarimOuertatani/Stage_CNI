package com.fitforge.api.coaching.controller;

import com.fitforge.api.coaching.dto.CoachingRelationshipResponse;
import com.fitforge.api.coaching.dto.CreateCoachingRequestRequest;
import com.fitforge.api.coaching.service.CoachingService;
import com.fitforge.api.common.enums.CoachingStatus;
import com.fitforge.api.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * API des relations de suivi : l'adherent envoie une demande, le coach y repond,
 * et chacun consulte / termine ses suivis.
 */
@RestController
@RequestMapping("/api/v1/coaching")
@RequiredArgsConstructor
@Tag(name = "Coaching", description = "Demandes de suivi et relations coach<->adherent")
public class CoachingController {

    private final CoachingService coachingService;

    // ── Adherent ─────────────────────────────────────────────────

    @PostMapping("/coaches/{coachUserId}/request")
    @Operation(summary = "Demander un suivi a un coach")
    public ResponseEntity<CoachingRelationshipResponse> request(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID coachUserId,
            @Valid @RequestBody CreateCoachingRequestRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(coachingService.requestCoaching(me.getId(), coachUserId, req.message()));
    }

    @GetMapping("/my")
    @Operation(summary = "Mes suivis / demandes (cote adherent)")
    public List<CoachingRelationshipResponse> myRelationships(@AuthenticationPrincipal UserPrincipal me) {
        return coachingService.getMemberRelationships(me.getId());
    }

    // ── Coach ────────────────────────────────────────────────────

    @GetMapping("/requests")
    @Operation(summary = "Relations recues (cote coach), filtrables par statut")
    public List<CoachingRelationshipResponse> coachRelationships(
            @AuthenticationPrincipal UserPrincipal me,
            @RequestParam(required = false) CoachingStatus status) {
        return coachingService.getCoachRelationships(me.getId(), status);
    }

    @PostMapping("/{relationshipId}/accept")
    @Operation(summary = "Accepter une demande de suivi")
    public CoachingRelationshipResponse accept(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID relationshipId) {
        return coachingService.respondToRequest(me.getId(), relationshipId, true);
    }

    @PostMapping("/{relationshipId}/decline")
    @Operation(summary = "Refuser une demande de suivi")
    public CoachingRelationshipResponse decline(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID relationshipId) {
        return coachingService.respondToRequest(me.getId(), relationshipId, false);
    }

    // ── Commun ───────────────────────────────────────────────────

    @GetMapping("/{relationshipId}")
    @Operation(summary = "Detail d'une relation de suivi")
    public CoachingRelationshipResponse getOne(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID relationshipId) {
        return coachingService.getRelationship(me.getId(), relationshipId);
    }

    @PostMapping("/{relationshipId}/end")
    @Operation(summary = "Terminer un suivi")
    public CoachingRelationshipResponse end(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID relationshipId) {
        return coachingService.endRelationship(me.getId(), relationshipId);
    }
}
