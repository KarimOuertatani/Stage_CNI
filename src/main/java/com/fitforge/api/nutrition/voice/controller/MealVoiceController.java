package com.fitforge.api.nutrition.voice.controller;

import com.fitforge.api.nutrition.voice.dto.AnalyzeTextRequest;
import com.fitforge.api.nutrition.voice.dto.VoiceAnalysisResponse;
import com.fitforge.api.nutrition.voice.service.MealVoiceAnalysisService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * Ajout d'un repas <b>a la voix</b>, ou par une phrase ecrite.
 *
 * <p><b>Endpoints volontairement en lecture seule.</b> Ils ne creent aucune
 * entree de journal : ils <i>proposent</i>. L'adherent corrige les quantites
 * comprises puis confirme les aliments qu'il retient, un par un, via
 * {@code POST /nutrition/from-food} — le chemin d'ecriture habituel, ou le
 * serveur recalcule les macros. Une seule source de verite, et l'analyse reste
 * annulable sans rien avoir a nettoyer.
 *
 * <p>Les deux routes renvoient exactement la meme structure : l'application
 * n'a qu'un seul ecran de resultats a gerer, quel que soit le mode de saisie.
 */
@RestController
@RequestMapping("/api/v1/nutrition")
@RequiredArgsConstructor
@Tag(name = "Nutrition", description = "Journal alimentaire : recherche d'aliments, repas, calories, macros")
public class MealVoiceController {

    private final MealVoiceAnalysisService service;

    @PostMapping(value = "/analyze-voice", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(
            summary = "Analyser une description vocale de repas",
            description = """
                    L'adherent dit ce qu'il a mange ; le serveur transcrit, extrait les
                    aliments et convertit les unites parlees en grammes (« deux oeufs »
                    -> 100 g), puis retrouve les macros de chacun.

                    NE PERSISTE RIEN : c'est une proposition. Pour l'enregistrer, appeler
                    POST /nutrition/from-food une fois par aliment retenu, avec le
                    foodItemId (ou a defaut le fdcId / offCode) et la quantite validee.

                    La transcription est toujours renvoyee, meme quand aucun aliment n'a
                    ete compris : elle permet a l'adherent de reperer un mot mal entendu,
                    de le corriger, et de relancer via POST /nutrition/analyze-text.

                    Un enregistrement sans aliment reconnaissable renvoie une liste vide
                    (200), jamais une erreur.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200",
                    description = "Aliments proposes (liste possiblement vide)"),
            @ApiResponse(responseCode = "400",
                    description = "Fichier invalide, quota atteint, ou analyse indisponible"),
            @ApiResponse(responseCode = "401",
                    description = "Token JWT absent ou invalide")
    })
    public VoiceAnalysisResponse analyzeVoice(@RequestParam("file") MultipartFile file) {
        return service.analyzeVoice(file);
    }

    @PostMapping("/analyze-text")
    @Operation(
            summary = "Analyser une description ecrite de repas",
            description = """
                    Meme traitement que /analyze-voice, a partir d'une phrase ecrite.

                    Deux usages : repli quand l'enregistrement vocal n'a pas pu etre
                    analyse, et correction quand la transcription comporte un mot mal
                    entendu.

                    NE PERSISTE RIEN.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200",
                    description = "Aliments proposes (liste possiblement vide)"),
            @ApiResponse(responseCode = "400",
                    description = "Description vide ou trop longue, ou analyse indisponible"),
            @ApiResponse(responseCode = "401",
                    description = "Token JWT absent ou invalide")
    })
    public VoiceAnalysisResponse analyzeText(@Valid @RequestBody AnalyzeTextRequest request) {
        return service.analyzeText(request.text());
    }
}
