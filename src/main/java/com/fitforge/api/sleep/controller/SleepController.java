package com.fitforge.api.sleep.controller;

import com.fitforge.api.security.UserPrincipal;
import com.fitforge.api.sleep.dto.SaveSleepRequest;
import com.fitforge.api.sleep.dto.SleepEntryResponse;
import com.fitforge.api.sleep.dto.SleepStatusResponse;
import com.fitforge.api.sleep.dto.SleepWeekResponse;
import com.fitforge.api.sleep.service.SleepService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.UUID;

/**
 * API du <b>journal de sommeil</b>.
 *
 * <p>Trois routes, qui suivent exactement le parcours de l'adherent : on lui
 * demande sa nuit au reveil, il la saisit, il consulte sa semaine.
 *
 * <p>Tout est porte par le JWT — aucune route ne prend d'identifiant
 * d'utilisateur, il n'existe donc aucun moyen de lire le sommeil de quelqu'un
 * d'autre.
 */
@RestController
@RequestMapping("/api/v1/sleep")
@RequiredArgsConstructor
@Tag(name = "Sommeil",
        description = "Journal de sommeil : saisie quotidienne, semaine, score et conseils")
public class SleepController {

    private final SleepService service;

    @GetMapping("/status")
    @Operation(
            summary = "Etat du sommeil pour aujourd'hui",
            description = """
                    Renvoie deux informations, demandees au meme moment par
                    l'application au lancement :

                    * `loggedToday` — la nuit d'aujourd'hui est-elle deja
                      saisie ? C'est ce qui decide de l'ouverture du pop-up.
                    * `latest` — la derniere nuit connue, **quelle que soit sa
                      date**, pour la tuile de l'accueil. Quelqu'un qui a saute
                      la saisie hier doit quand meme voir sa derniere nuit :
                      une tuile qui repasse a « — » donne l'impression d'avoir
                      perdu son historique.""")
    public SleepStatusResponse status(@AuthenticationPrincipal UserPrincipal me) {
        return service.status(me.getId());
    }

    @PostMapping
    @Operation(
            summary = "Enregistrer (ou corriger) une nuit",
            description = """
                    L'adherent saisit son **heure de coucher** et son **heure de
                    lever** ; le serveur en deduit la duree, passage de minuit
                    compris.

                    UPSERT : renvoyer sa nuit pour une date deja saisie la
                    **corrige** au lieu d'en creer une seconde. Se tromper d'une
                    heure et rouvrir le formulaire est le cas normal, pas une
                    exception.

                    La reponse porte la **tranche**, un **titre** et le
                    **conseil** correspondant — calcules par une regle ecrite,
                    sans appel a un modele de langage : la comparaison d'une
                    duree a un intervalle a une reponse fixe, elle doit etre
                    instantanee et identique a elle-meme.

                    Effet de bord voulu : la moyenne de sommeil du profil est
                    recalculee sur trente jours. Le coach IA et le generateur de
                    programme, qui la lisent deja, deviennent plus justes.""")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Nuit enregistree, avec son conseil"),
            @ApiResponse(responseCode = "400",
                    description = "Heures manquantes, nuit dans le futur, "
                            + "ou duree invraisemblable (moins de 15 min, plus de 16 h)"),
            @ApiResponse(responseCode = "401", description = "Token JWT absent ou invalide")
    })
    public SleepEntryResponse save(
            @AuthenticationPrincipal UserPrincipal me,
            @Valid @RequestBody SaveSleepRequest request) {
        return service.save(me.getId(), request);
    }

    @GetMapping("/week")
    @Operation(
            summary = "Une semaine de sommeil",
            description = """
                    Renvoie **toujours sept jours**, du lundi au dimanche, les
                    jours sans saisie compris (duree nulle). C'est ce qui permet
                    a l'histogramme d'afficher des colonnes creuses aux bons
                    endroits plutot que de tasser les barres — quatre barres
                    serrees se lisent comme quatre jours consecutifs.

                    Avec la moyenne, le **score 0-100** (duree 70 points,
                    regularite des heures de coucher 30 points), l'ecart
                    week-end / semaine et deux a trois conseils.

                    `start` accepte **n'importe quelle date de la semaine
                    voulue** — le serveur remonte au lundi lui-meme. L'app n'a
                    donc pas a savoir ou commence une semaine.""")
    public SleepWeekResponse week(
            @AuthenticationPrincipal UserPrincipal me,
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate start) {
        return service.week(me.getId(), start);
    }

    @DeleteMapping("/{id}")
    @Operation(
            summary = "Supprimer une nuit",
            description = "Pour retirer une saisie erronee. La moyenne du profil "
                    + "est recalculee dans la foulee.")
    public ResponseEntity<Void> delete(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID id) {
        service.delete(me.getId(), id);
        return ResponseEntity.noContent().build();
    }
}
