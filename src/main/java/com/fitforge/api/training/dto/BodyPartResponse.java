package com.fitforge.api.training.dto;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * Zone du corps proposee dans la navigation « Parcourir par zone ».
 */
@Schema(description = "Partie du corps (navigation par zone)")
public record BodyPartResponse(
        String name,           // code ExerciseDB (CHEST, BACK...)
        String labelFr,        // libelle affiche
        String imageUrl,       // illustration (CDN, .webp) - repli
        String photoUrl,       // photo representative d'un exercice (.jpg) - principal
        long exerciseCount     // nombre d'exercices rattaches
) {}
