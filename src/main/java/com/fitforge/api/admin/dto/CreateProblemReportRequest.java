package com.fitforge.api.admin.dto;

import com.fitforge.api.common.enums.ProblemCategory;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Ce qu'un utilisateur envoie quand il signale un probleme.
 *
 * <h2>Le minimum de 20 caracteres sur la description</h2>
 * Il ne s'agit pas de compliquer la vie de l'utilisateur mais de rendre le
 * signalement <b>traitable</b>. « ca marche pas » satisfait un {@code @NotBlank}
 * et ne permet aucune action : ni de reproduire, ni de repondre, ni meme de
 * savoir de quel ecran on parle. Le seul resultat serait un aller-retour pour
 * demander des precisions, auquel la plupart des gens ne repondent pas.
 *
 * <p>{@code platform} et {@code appVersion} ne sont pas saisis : l'application
 * les remplit seule.
 */
@Schema(description = "Signalement d'un probleme")
public record CreateProblemReportRequest(

        @NotNull(message = "Choisis une categorie")
        ProblemCategory category,

        @NotBlank(message = "Le sujet est obligatoire")
        @Size(max = 150, message = "Le sujet ne peut pas depasser 150 caracteres")
        @Schema(example = "Le minuteur de repos ne se declenche pas")
        String subject,

        @NotBlank(message = "La description est obligatoire")
        @Size(min = 20, max = 4000,
                message = "Decris le probleme en 20 caracteres au moins : ce qui s'est passe, et sur quel ecran")
        String description,

        @Schema(description = "URL d'une capture d'ecran deja televersee via POST /media")
        String attachmentUrl,

        @Schema(description = "Renseigne par l'application", example = "android 14")
        @Size(max = 100)
        String platform,

        @Schema(description = "Renseigne par l'application", example = "1.0.0+1")
        @Size(max = 100)
        String appVersion
) {}
