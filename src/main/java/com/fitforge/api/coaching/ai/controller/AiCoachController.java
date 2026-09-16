package com.fitforge.api.coaching.ai.controller;

import com.fitforge.api.coaching.ai.dto.AiCoachMessageResponse;
import com.fitforge.api.coaching.ai.dto.AskCoachRequest;
import com.fitforge.api.coaching.ai.service.AiCoachService;
import com.fitforge.api.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * API du <b>coach IA</b> : un fil de discussion prive, borne au sport.
 *
 * <p><b>Un seul fil par adherent</b>, et il n'appartient qu'a lui : toutes les
 * routes sont portees par le JWT, aucune ne prend d'identifiant d'utilisateur.
 * Il n'existe donc aucun moyen de lire la conversation de quelqu'un d'autre.
 *
 * <p><b>Perimetre</b> : entrainement, nutrition, blessures liees au sport,
 * motivation sportive. Toute autre demande est declinee — et c'est
 * <b>l'application</b> qui ecrit le refus, pas le modele
 * (voir {@code AiCoachService}).
 *
 * <p>Le coach IA <b>complete</b> les coachs humains de l'application, il ne les
 * remplace pas : il est disponible a toute heure, sans demande de suivi.
 */
@RestController
@RequestMapping("/api/v1/coach-ai")
@RequiredArgsConstructor
@Tag(name = "Coach IA",
        description = "Coach sportif IA : entrainement, nutrition, blessures liees au sport")
public class AiCoachController {

    private final AiCoachService service;

    @GetMapping("/messages")
    @Operation(
            summary = "Mon fil avec le coach IA",
            description = """
                    Le fil complet de l'adherent connecte, du plus ancien au plus
                    recent. Liste vide s'il n'a jamais ecrit.

                    Les reponses portent leur `topic` et le drapeau `refused` :
                    l'application s'en sert pour signaler visuellement une demande
                    declinee ou un conseil portant sur une blessure.""")
    public List<AiCoachMessageResponse> history(@AuthenticationPrincipal UserPrincipal me) {
        return service.history(me.getId());
    }

    @GetMapping("/status")
    @Operation(
            summary = "Le coach IA est-il disponible ?",
            description = """
                    Renvoie `{ "available": true|false }`.

                    Faux quand aucune cle Gemini n'est configuree sur le serveur.
                    L'application s'en sert pour masquer l'entree du coach IA au
                    lieu d'afficher un bouton qui ne mene qu'a une erreur.""")
    public Map<String, Boolean> status() {
        return Map.of("available", service.isAvailable());
    }

    @PostMapping("/messages")
    @Operation(
            summary = "Poser une question au coach IA",
            description = """
                    Enregistre la question, obtient la reponse et renvoie
                    **la reponse du coach** (l'application connait deja la question).

                    Les derniers messages du fil sont renvoyes au modele comme
                    contexte, avec un resume du profil de l'adherent (objectif,
                    niveau, materiel, blessures connues) : c'est ce qui distingue un
                    conseil personnalise d'une reponse generique.

                    PERIMETRE : une demande etrangere au sport recoit une reponse
                    `refused = true` avec `topic = HORS_SUJET`. Ce n'est pas une
                    erreur HTTP — la conversation continue normalement.

                    BLESSURES : aucun medicament, aucune posologie, aucun
                    diagnostic. La reponse porte toujours une invitation a
                    consulter un professionnel de sante.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200",
                    description = "Reponse du coach (possiblement un refus de perimetre)"),
            @ApiResponse(responseCode = "400",
                    description = "Question vide ou trop longue, plafond horaire atteint, "
                            + "ou coach IA indisponible"),
            @ApiResponse(responseCode = "401",
                    description = "Token JWT absent ou invalide")
    })
    public AiCoachMessageResponse ask(
            @AuthenticationPrincipal UserPrincipal me,
            @Valid @RequestBody AskCoachRequest request) {
        return service.ask(me.getId(), request.text());
    }

    @DeleteMapping("/messages")
    @Operation(
            summary = "Effacer mon fil",
            description = """
                    Supprime tout l'historique de l'adherent connecte — « nouvelle
                    conversation ». Le coach repart alors sans memoire des echanges
                    precedents.""")
    public ResponseEntity<Void> clear(@AuthenticationPrincipal UserPrincipal me) {
        service.clear(me.getId());
        return ResponseEntity.status(HttpStatus.NO_CONTENT).build();
    }
}
