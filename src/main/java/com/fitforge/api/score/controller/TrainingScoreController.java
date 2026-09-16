package com.fitforge.api.score.controller;

import com.fitforge.api.score.dto.TrainingScoreResponse;
import com.fitforge.api.score.service.TrainingScoreService;
import com.fitforge.api.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * API du score d'entrainement.
 */
@RestController
@RequestMapping("/api/v1/score")
@RequiredArgsConstructor
@Tag(name = "Score", description = "Score d'entrainement hebdomadaire (charge + assiduite)")
public class TrainingScoreController {

    private final TrainingScoreService service;

    @GetMapping("/current")
    @Operation(summary = "Mon score le plus recent")
    public TrainingScoreResponse current(@AuthenticationPrincipal UserPrincipal me) {
        return service.getCurrent(me.getId());
    }

    @GetMapping("/history")
    @Operation(summary = "Evolution de mon score sur les N dernieres semaines")
    public List<TrainingScoreResponse> history(
            @AuthenticationPrincipal UserPrincipal me,
            @RequestParam(defaultValue = "12") int weeks) {
        return service.getHistory(me.getId(), weeks);
    }

    @PostMapping("/recompute")
    @Operation(summary = "Recalculer mon score (a declencher apres une seance)")
    public TrainingScoreResponse recompute(@AuthenticationPrincipal UserPrincipal me) {
        return service.recompute(me.getId());
    }
}
