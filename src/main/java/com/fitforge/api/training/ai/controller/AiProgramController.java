package com.fitforge.api.training.ai.controller;

import com.fitforge.api.security.UserPrincipal;
import com.fitforge.api.training.ai.dto.GenerateProgramRequest;
import com.fitforge.api.training.ai.service.AiProgramService;
import com.fitforge.api.training.dto.ProgramResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
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

import java.util.Map;

/**
 * API du <b>generateur de programme</b> de l'IA FitForge.
 *
 * <p>L'adherent repond a un questionnaire, le serveur y joint son profil et
 * fournit au modele la liste des exercices <b>reellement realisables</b> par
 * lui. Le programme produit est materialise immediatement : il apparait dans
 * « Mes programmes » comme n'importe quel autre, et se modifie de la meme
 * facon.
 *
 * <p>Deux routes seulement, montees sous {@code /programs/ai} pour rester dans
 * la famille des programmes plutot que de creer un domaine a part : ce qui est
 * genere ici n'est pas d'une autre nature que ce qu'un coach compose a la main.
 */
@RestController
@RequestMapping("/api/v1/programs/ai")
@RequiredArgsConstructor
@Tag(name = "Programme IA",
        description = "Generation d'un programme d'entrainement complet par l'IA FitForge")
public class AiProgramController {

    private final AiProgramService service;

    @GetMapping("/status")
    @Operation(
            summary = "La generation par l'IA est-elle disponible ?",
            description = """
                    Renvoie `{ "available": true|false }`.

                    Faux quand aucune cle Gemini n'est configuree sur le serveur.
                    L'application s'en sert pour masquer l'entree « Creer avec
                    l'IA » au lieu d'afficher un bouton qui ne mene qu'a une
                    erreur.""")
    public Map<String, Boolean> status() {
        return Map.of("available", service.isAvailable());
    }

    @PostMapping("/generate")
    @Operation(
            summary = "Generer un programme complet avec l'IA",
            description = """
                    Compose un programme a partir du questionnaire, l'enregistre
                    au nom de l'adherent connecte et le renvoie **complet**
                    (seances + exercices places, avec leurs objectifs).

                    Le profil de l'adherent (niveau, materiel, blessures
                    declarees, poids, sommeil) est joint automatiquement : il n'a
                    pas a le ressaisir. Quand le questionnaire et le profil se
                    contredisent, **le questionnaire l'emporte**.

                    Les exercices sont choisis dans le referentiel de
                    l'application, filtre selon le materiel disponible : le
                    programme genere ne peut donc contenir que des exercices qui
                    existent, avec leur video de demonstration.

                    Le programme cree est un programme **ordinaire** : il porte
                    `generatedByAi = true` et son champ `aiRationale` explique
                    les choix de composition, mais il se modifie, s'enrichit et
                    se supprime comme les autres.

                    PLAFOND : quelques generations par adherent et par 24 heures
                    (une generation est l'appel le plus lourd de l'application).
                    Les tentatives qui echouent comptent aussi — elles consomment
                    le meme quota.""")
    @ApiResponses({
            @ApiResponse(responseCode = "201",
                    description = "Programme genere et enregistre"),
            @ApiResponse(responseCode = "400",
                    description = "Questionnaire invalide, plafond journalier atteint, "
                            + "generation indisponible ou reponse inexploitable"),
            @ApiResponse(responseCode = "401",
                    description = "Token JWT absent ou invalide")
    })
    public ResponseEntity<ProgramResponse> generate(
            @AuthenticationPrincipal UserPrincipal me,
            @Valid @RequestBody GenerateProgramRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(service.generate(me.getId(), request));
    }
}
