package com.fitforge.api.user.controller;

import com.fitforge.api.security.UserPrincipal;
import com.fitforge.api.user.dto.ProfileResponse;
import com.fitforge.api.user.dto.UpdateProfileRequest;
import com.fitforge.api.user.service.ProfileService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * API du profil physique/sportif de l'adherent connecte.
 * Toutes les routes sont protegees (JWT obligatoire).
 */
@RestController
@RequestMapping("/api/v1/profile")
@RequiredArgsConstructor
@Tag(name = "Profil", description = "Donnees physiques et sportives de l'adherent")
public class ProfileController {

    private final ProfileService service;

    @GetMapping
    @Operation(summary = "Recuperer mon profil complet")
    public ProfileResponse getMyProfile(@AuthenticationPrincipal UserPrincipal me) {
        return service.getMyProfile(me.getId());
    }

    @PutMapping
    @Operation(summary = "Creer ou mettre a jour mon profil (poids, taille, objectif, blessures...)")
    public ProfileResponse updateMyProfile(
            @AuthenticationPrincipal UserPrincipal me,
            @Valid @RequestBody UpdateProfileRequest req) {
        return service.updateMyProfile(me.getId(), req);
    }
}
