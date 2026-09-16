package com.fitforge.api.admin.controller;

import com.fitforge.api.admin.dto.AdminUserDetail;
import com.fitforge.api.admin.dto.AdminUserSummary;
import com.fitforge.api.admin.service.AdminUserService;
import com.fitforge.api.common.dto.PageResponse;
import com.fitforge.api.common.enums.Role;
import com.fitforge.api.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

/** Gestion des comptes depuis la console (role ADMIN). */
@RestController
@RequestMapping("/api/v1/admin/users")
@RequiredArgsConstructor
@Tag(name = "Admin - Membres", description = "Consultation et suspension des comptes (role ADMIN)")
public class AdminUserController {

    private final AdminUserService service;

    @GetMapping
    @Operation(summary = "Tableau des membres : recherche par nom ou email, filtres role et etat")
    public PageResponse<AdminUserSummary> list(
            @RequestParam(required = false) Role role,
            @RequestParam(required = false) Boolean enabled,
            @RequestParam(required = false) String query,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return service.list(role, enabled, query, page, size);
    }

    @GetMapping("/{userId}")
    @Operation(summary = "Fiche d'un membre : compte, profil sportif et compteurs d'activite")
    public AdminUserDetail detail(@PathVariable UUID userId) {
        return service.detail(userId);
    }

    @PostMapping("/{userId}/suspend")
    @Operation(summary = "Suspendre un compte (reversible, aucune donnee effacee)")
    public AdminUserDetail suspend(
            @AuthenticationPrincipal UserPrincipal admin,
            @PathVariable UUID userId) {
        return service.suspend(admin.getId(), userId);
    }

    @PostMapping("/{userId}/reactivate")
    @Operation(summary = "Reactiver un compte suspendu")
    public AdminUserDetail reactivate(
            @AuthenticationPrincipal UserPrincipal admin,
            @PathVariable UUID userId) {
        return service.reactivate(admin.getId(), userId);
    }
}
