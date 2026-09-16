package com.fitforge.api.nutrition.voice.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Description <b>ecrite</b> d'un repas, en langage naturel.
 *
 * <p>Deux usages :
 * <ul>
 *   <li><b>repli</b> quand l'enregistrement vocal n'a pas pu etre analyse
 *       (format refuse, micro inaudible) ;</li>
 *   <li><b>correction</b> : l'adherent modifie la transcription affichee — un
 *       mot mal entendu — et relance l'analyse.</li>
 * </ul>
 *
 * <p>La borne haute protege le quota : une description de repas tient en deux
 * phrases, pas en un chapitre.
 */
@Schema(description = "Description d'un repas en langage naturel")
public record AnalyzeTextRequest(

        @Schema(description = "Ce que l'adherent a mange, en francais courant",
                example = "Ce midi j'ai mange deux oeufs, une tranche de pain complet "
                        + "et un yaourt nature")
        @NotBlank(message = "decrivez ce que vous avez mange")
        @Size(min = 3, max = 1000, message = "la description doit faire entre 3 et 1000 caracteres")
        String text
) {
}
