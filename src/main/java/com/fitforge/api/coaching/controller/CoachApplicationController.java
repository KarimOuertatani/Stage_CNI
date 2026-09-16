package com.fitforge.api.coaching.controller;

import com.fitforge.api.coaching.dto.CoachApplicationResponse;
import com.fitforge.api.coaching.service.CoachApplicationService;
import com.fitforge.api.common.enums.CoachDocumentType;
import com.fitforge.api.security.UserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

/**
 * Candidature du coach connecte : depot des justificatifs et soumission.
 *
 * <h2>Pourquoi une route separee de {@code /coach/me}</h2>
 * {@code /coach/me} edite le <b>contenu</b> du profil (accroche, biographie,
 * titres revendiques) ; ces routes-ci gerent l'<b>etat</b> de la candidature et
 * ses pieces jointes. Les melanger obligerait un simple enregistrement de
 * biographie a transporter des fichiers, et rendrait impossible de distinguer
 * « je corrige une faute de frappe » de « je redepose mon dossier ».
 *
 * <p>Toutes les routes sont sous {@code /api/v1}, donc protegees par le filtre
 * JWT, et operent exclusivement sur le dossier de l'appelant : aucune d'elles ne
 * prend d'identifiant de coach en parametre.
 */
@RestController
@RequestMapping("/api/v1/coach-application")
@RequiredArgsConstructor
@Validated
@Tag(name = "Candidature coach",
        description = "Depot des justificatifs et soumission du dossier a l'administration")
public class CoachApplicationController {

    private final CoachApplicationService applicationService;

    @GetMapping
    @Operation(summary = "Etat de ma candidature (statut, pieces, ce qu'il manque)")
    public CoachApplicationResponse myApplication(@AuthenticationPrincipal UserPrincipal me) {
        return applicationService.getMyApplication(me.getId());
    }

    @PostMapping(value = "/documents", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Deposer un justificatif (piece d'identite, diplome, certificat)")
    public CoachApplicationResponse uploadDocument(
            @AuthenticationPrincipal UserPrincipal me,
            @RequestParam("type") CoachDocumentType type,
            @RequestParam(value = "label", required = false)
            @Size(max = 255, message = "L'intitule ne peut pas depasser 255 caracteres") String label,
            @RequestParam("file") MultipartFile file) {
        return applicationService.uploadDocument(me.getId(), type, label, file);
    }

    @DeleteMapping("/documents/{documentId}")
    @Operation(summary = "Retirer un justificatif de mon dossier")
    public CoachApplicationResponse deleteDocument(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID documentId) {
        return applicationService.deleteDocument(me.getId(), documentId);
    }

    /**
     * Telecharge le fichier d'un justificatif.
     *
     * <h2>La seule porte d'entree vers un fichier prive</h2>
     * Ces fichiers ne sont servis par <b>aucune</b> route statique -- contrairement
     * a {@code /media/**}, qui est en {@code permitAll}. Le controle des droits est
     * fait par le service a chaque appel : administrateur ou proprietaire, et
     * personne d'autre.
     *
     * <p>{@code Content-Disposition: inline} : la console d'administration affiche
     * la piece dans une visionneuse, elle ne la telecharge pas. Un examen ou
     * chaque document oblige a ouvrir un fichier depuis le disque serait
     * insupportable sur un dossier de cinq pieces.
     *
     * <p>La route vit ici plutot que sous {@code /admin} parce que le coach
     * lui-meme doit pouvoir relire ce qu'il a envoye : la placer sous
     * {@code /admin} l'aurait interdit par la regle de securite.
     */
    @GetMapping("/documents/{documentId}/file")
    @Operation(summary = "Ouvrir un justificatif (admin ou proprietaire uniquement)")
    public ResponseEntity<Resource> documentFile(
            @AuthenticationPrincipal UserPrincipal me,
            @PathVariable UUID documentId) {

        CoachApplicationService.DocumentFile file =
                applicationService.loadDocumentFile(me.getId(), documentId);

        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(file.contentType()))
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "inline; filename=\"" + sanitize(file.fileName()) + "\"")
                // Ces fichiers ne doivent finir dans aucun cache partage.
                .header(HttpHeaders.CACHE_CONTROL, "private, no-store")
                .body(file.resource());
    }

    @PostMapping("/submit")
    @Operation(summary = "Soumettre mon dossier a l'examen de l'administration")
    public CoachApplicationResponse submit(@AuthenticationPrincipal UserPrincipal me) {
        return applicationService.submit(me.getId());
    }

    /**
     * Neutralise les guillemets et sauts de ligne d'un nom de fichier avant de
     * l'inserer dans un en-tete HTTP. Un nom contenant {@code "} ou un CRLF
     * permettrait sinon d'injecter des en-tetes arbitraires dans la reponse.
     */
    private String sanitize(String fileName) {
        return fileName.replaceAll("[\"\\r\\n]", "_");
    }
}
