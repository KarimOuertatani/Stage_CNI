package com.fitforge.api.presence.controller;

import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.presence.dto.PresenceResponse;
import com.fitforge.api.presence.service.PresenceService;
import com.fitforge.api.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * Consultation de la presence des interlocuteurs.
 *
 * <p><b>Role exact de ces endpoints :</b> donner l'etat <i>initial</i> a
 * l'ouverture d'un ecran. Les changements qui suivent arrivent tout seuls par
 * WebSocket sur {@code /user/queue/presence} — l'application ne fait donc
 * <b>aucun sondage</b>.
 *
 * <p><b>Confidentialite.</b> La presence est une donnee personnelle : on ne
 * peut consulter que la sienne ou celle d'un interlocuteur d'un suivi actif.
 * Toute autre demande repond 404 (et non 403) pour ne pas confirmer
 * l'existence du compte vise.
 */
@RestController
@RequestMapping("/api/v1/presence")
@RequiredArgsConstructor
@Tag(name = "Presence", description = "Statut en ligne et derniere activite des interlocuteurs")
public class PresenceController {

    private final PresenceService presence;

    @GetMapping("/partners")
    @Operation(
            summary = "Presence de tous mes interlocuteurs",
            description = """
                    Etat de chaque personne avec qui j'ai un suivi ACCEPTED.
                    Concu pour la liste des conversations : un seul appel pour
                    tout l'ecran, puis mises a jour temps reel par WebSocket.""")
    public List<PresenceResponse> myPartners(@AuthenticationPrincipal UserPrincipal me) {
        return presence.presenceOfPartners(me.getId());
    }

    @GetMapping("/{userId}")
    @Operation(
            summary = "Presence d'un interlocuteur",
            description = """
                    Appele a l'ouverture d'une conversation pour afficher
                    immediatement « En ligne » ou « Vu il y a ... », sans
                    attendre le premier evenement WebSocket.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Etat de presence"),
            @ApiResponse(responseCode = "404", description = "Compte inconnu ou non autorise"),
            @ApiResponse(responseCode = "401", description = "Token JWT absent ou invalide")
    })
    public PresenceResponse of(@AuthenticationPrincipal UserPrincipal me,
                               @PathVariable UUID userId) {
        if (!presence.canSee(me.getId(), userId)) {
            throw new ResourceNotFoundException("Utilisateur introuvable");
        }
        return presence.presenceOf(userId);
    }
}
