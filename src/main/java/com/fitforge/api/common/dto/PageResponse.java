package com.fitforge.api.common.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import org.springframework.data.domain.Page;

import java.util.List;
import java.util.function.Function;

/**
 * Forme unique des reponses paginees de l'API.
 *
 * <h2>Pourquoi ne pas renvoyer directement un {@code Page} de Spring Data ?</h2>
 * Parce que sa serialisation JSON expose une quinzaine de champs internes
 * ({@code pageable}, {@code sort.sorted}, {@code sort.unsorted}, {@code first},
 * {@code numberOfElements}...) dont la forme <b>a deja change entre deux
 * versions de Spring</b>. Les clients qui s'y adossent cassent a la montee de
 * version, et Spring lui-meme journalise un avertissement a ce sujet.
 *
 * <p>Ce record fige le contrat cote API : cinq champs, choisis parce qu'une
 * console en a reellement besoin -- afficher les lignes, savoir ou l'on en est,
 * et decider si le bouton « page suivante » doit exister.
 */
@Schema(description = "Reponse paginee")
public record PageResponse<T>(

        List<T> items,

        @Schema(description = "Index de la page courante, a partir de 0", example = "0")
        int page,

        @Schema(description = "Nombre d'elements par page", example = "20")
        int size,

        @Schema(description = "Nombre total d'elements, toutes pages confondues", example = "137")
        long totalElements,

        @Schema(description = "Nombre total de pages", example = "7")
        int totalPages
) {
    /** Convertit une page Spring Data en appliquant un mapper a chaque element. */
    public static <E, T> PageResponse<T> of(Page<E> page, Function<E, T> mapper) {
        return new PageResponse<>(
                page.getContent().stream().map(mapper).toList(),
                page.getNumber(),
                page.getSize(),
                page.getTotalElements(),
                page.getTotalPages());
    }
}
