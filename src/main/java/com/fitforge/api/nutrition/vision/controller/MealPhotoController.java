package com.fitforge.api.nutrition.vision.controller;

import com.fitforge.api.nutrition.vision.dto.PhotoAnalysisResponse;
import com.fitforge.api.nutrition.vision.service.MealPhotoAnalysisService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * Analyse d'une photo de repas.
 *
 * <p><b>Endpoint volontairement en lecture seule.</b> Il ne cree aucune entree
 * de journal : il <i>propose</i>. L'adherent corrige les quantites estimees
 * puis confirme les aliments qu'il retient, un par un, via
 * {@code POST /nutrition/from-food} — le chemin d'ecriture habituel, ou le
 * serveur recalcule les macros. Une seule source de verite, et l'analyse reste
 * annulable sans rien avoir a nettoyer.
 */
@RestController
@RequestMapping("/api/v1/nutrition")
@RequiredArgsConstructor
@Tag(name = "Nutrition", description = "Journal alimentaire : recherche d'aliments, repas, calories, macros")
public class MealPhotoController {

    private final MealPhotoAnalysisService service;

    @PostMapping(value = "/analyze-photo", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(
            summary = "Analyser une photo de repas",
            description = """
                    Identifie les aliments visibles sur la photo, estime leurs quantites
                    et renvoie les macros correspondantes.

                    NE PERSISTE RIEN : c'est une proposition. Pour l'enregistrer, appeler
                    POST /nutrition/from-food une fois par aliment retenu, avec le
                    foodItemId (ou a defaut le fdcId) et la quantite validee.

                    Un aliment vu mais introuvable au catalogue est renvoye avec
                    matched = false et des macros nulles : il reste affichable, mais doit
                    passer par la saisie manuelle.

                    Une photo sans aliment reconnaissable renvoie une liste vide (200),
                    jamais une erreur.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200",
                    description = "Aliments proposes (liste possiblement vide)"),
            @ApiResponse(responseCode = "400",
                    description = "Fichier invalide, quota atteint, ou analyse indisponible"),
            @ApiResponse(responseCode = "401",
                    description = "Token JWT absent ou invalide")
    })
    public PhotoAnalysisResponse analyzePhoto(@RequestParam("file") MultipartFile file) {
        return service.analyze(file);
    }
}
