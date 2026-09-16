package com.fitforge.api.coaching.controller;

import com.fitforge.api.coaching.dto.CoachDashboardResponse;
import com.fitforge.api.coaching.dto.CoachProfileResponse;
import com.fitforge.api.coaching.dto.CoachSummaryResponse;
import com.fitforge.api.coaching.dto.UpsertCoachProfileRequest;
import com.fitforge.api.coaching.service.CoachService;
import com.fitforge.api.coaching.service.CoachingService;
import com.fitforge.api.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * API des coachs : annuaire + consultation de profil (cote adherent), et
 * edition de son propre profil + tableau de bord (cote coach).
 */
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
@Tag(name = "Coachs", description = "Annuaire, profils et tableau de bord coach")
public class CoachController {

    private final CoachService coachService;
    private final CoachingService coachingService;

    // ── Annuaire / consultation (adherent) ───────────────────────

    @GetMapping("/coaches")
    @Operation(summary = "Annuaire des coachs disponibles")
    public List<CoachSummaryResponse> directory(@AuthenticationPrincipal UserPrincipal me) {
        return coachService.getDirectory(me.getId());
    }

    @GetMapping("/coaches/{userId}")
    @Operation(summary = "Profil complet d'un coach")
    public CoachProfileResponse coachProfile(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID userId) {
        return coachService.getCoachProfile(me.getId(), userId);
    }

    // ── Profil du coach connecte ─────────────────────────────────

    @GetMapping("/coach/me")
    @Operation(summary = "Mon profil coach")
    public CoachProfileResponse myProfile(@AuthenticationPrincipal UserPrincipal me) {
        return coachService.getMyProfile(me.getId());
    }

    @PutMapping("/coach/me")
    @Operation(summary = "Creer / mettre a jour mon profil coach")
    public CoachProfileResponse upsertMyProfile(
            @AuthenticationPrincipal UserPrincipal me,
            @Valid @RequestBody UpsertCoachProfileRequest req) {
        return coachService.upsertMyProfile(me.getId(), req);
    }

    @GetMapping("/coach/dashboard")
    @Operation(summary = "Tableau de bord du coach (compteurs)")
    public CoachDashboardResponse dashboard(@AuthenticationPrincipal UserPrincipal me) {
        return coachingService.getDashboard(me.getId());
    }
}
