package com.fitforge.api.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Motif accompagnant un refus ou une suspension.
 *
 * <h2>Pourquoi {@code @NotBlank} et non un champ facultatif</h2>
 * Parce que ce texte est <b>envoye tel quel au coach</b>, par email et dans
 * l'application. Un refus sans motif produit exactement la situation qu'on
 * cherche a eviter : un coach qui ne sait pas quoi corriger, resoumet le meme
 * dossier, et occupe une seconde fois le temps de l'administrateur.
 *
 * <p>Le minimum de 10 caracteres n'est pas une coquetterie : sans lui, « non »
 * satisferait la contrainte et l'email partirait avec ce seul mot.
 */
@Schema(description = "Decision de l'administrateur sur un dossier")
public record ReviewDecisionRequest(

        @NotBlank(message = "Un motif est obligatoire : le coach le recevra tel quel")
        @Size(min = 10, max = 1000,
                message = "Le motif doit faire entre 10 et 1000 caracteres")
        @Schema(description = "Motif communique au coach",
                example = "La photo de ta piece d'identite est floue : les quatre coins doivent etre visibles.")
        String reason
) {}
