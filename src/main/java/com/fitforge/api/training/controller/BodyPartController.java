package com.fitforge.api.training.controller;

import com.fitforge.api.training.dto.BodyPartResponse;
import com.fitforge.api.training.service.BodyPartService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * API de navigation « par zone du corps » : liste des parties du corps
 * disponibles (avec image + nombre d'exercices). Les exercices d'une zone se
 * recuperent ensuite via {@code GET /exercises?bodyPart=CHEST}.
 */
@RestController
@RequestMapping("/api/v1/bodyparts")
@RequiredArgsConstructor
@Tag(name = "Parties du corps", description = "Navigation des exercices par zone")
public class BodyPartController {

    private final BodyPartService service;

    @GetMapping
    @Operation(summary = "Lister les parties du corps (image + nombre d'exercices)")
    public List<BodyPartResponse> list() {
        return service.listWithCounts();
    }
}
