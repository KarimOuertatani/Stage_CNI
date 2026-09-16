package com.fitforge.api.training.importer;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * DTOs de deserialisation des reponses de l'API EXERCISEDB V2 (AscendAPI).
 *
 * <p>Regroupes ici car ils ne servent qu'au service d'import et ne doivent
 * jamais fuiter vers le client Flutter (qui consomme notre propre
 * {@code ExerciseResponse}). {@code @JsonIgnoreProperties(ignoreUnknown=true)}
 * protege contre l'ajout futur de champs cote API.
 */
public final class ExerciseDbDtos {

    private ExerciseDbDtos() {
    }

    /** Meta de pagination par curseur (endpoint liste). */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record ListMeta(
            @JsonProperty("total") Integer total,
            @JsonProperty("hasNextPage") Boolean hasNextPage,
            @JsonProperty("hasPreviousPage") Boolean hasPreviousPage,
            @JsonProperty("nextCursor") String nextCursor,
            @JsonProperty("previousCursor") String previousCursor
    ) {
    }

    /** Element d'aperçu renvoye par l'endpoint liste (sans video ni instructions). */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record ListItem(
            @JsonProperty("exerciseId") String exerciseId,
            @JsonProperty("name") String name,
            @JsonProperty("equipments") List<String> equipments,
            @JsonProperty("bodyParts") List<String> bodyParts,
            @JsonProperty("exerciseType") String exerciseType,
            @JsonProperty("targetMuscles") List<String> targetMuscles,
            @JsonProperty("secondaryMuscles") List<String> secondaryMuscles,
            @JsonProperty("imageUrl") String imageUrl,
            @JsonProperty("keywords") List<String> keywords
    ) {
    }

    /** Reponse de l'endpoint liste GET /api/v1/exercises. */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record ListResponse(
            @JsonProperty("success") Boolean success,
            @JsonProperty("meta") ListMeta meta,
            @JsonProperty("data") List<ListItem> data
    ) {
    }

    /** Images multi-resolutions (cles "360p", "480p", "720p", "1080p"). */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record ImageUrls(
            @JsonProperty("360p") String p360,
            @JsonProperty("480p") String p480,
            @JsonProperty("720p") String p720,
            @JsonProperty("1080p") String p1080
    ) {
    }

    /** Exercice complet renvoye par l'endpoint detail (avec video + instructions). */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Detail(
            @JsonProperty("exerciseId") String exerciseId,
            @JsonProperty("name") String name,
            @JsonProperty("imageUrl") String imageUrl,
            @JsonProperty("imageUrls") ImageUrls imageUrls,
            @JsonProperty("equipments") List<String> equipments,
            @JsonProperty("bodyParts") List<String> bodyParts,
            @JsonProperty("exerciseType") String exerciseType,
            @JsonProperty("targetMuscles") List<String> targetMuscles,
            @JsonProperty("secondaryMuscles") List<String> secondaryMuscles,
            @JsonProperty("videoUrl") String videoUrl,
            @JsonProperty("keywords") List<String> keywords,
            @JsonProperty("overview") String overview,
            @JsonProperty("instructions") List<String> instructions,
            @JsonProperty("exerciseTips") List<String> exerciseTips,
            @JsonProperty("variations") List<String> variations,
            @JsonProperty("relatedExerciseIds") List<String> relatedExerciseIds
    ) {
    }

    /** Reponse de l'endpoint detail GET /api/v1/exercises/{id}. */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record DetailResponse(
            @JsonProperty("success") Boolean success,
            @JsonProperty("data") Detail data
    ) {
    }
}
