package com.fitforge.api.training.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Partie du corps de reference (referentiel {@code body_parts}, migration V9).
 * Alimente la navigation « Parcourir par zone » cote app : libelle FR + image
 * illustrative. Les exercices s'y rattachent par leur colonne texte
 * {@code body_part} (valeurs ExerciseDB en majuscules).
 */
@Entity
@Table(name = "body_parts")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class BodyPart {

    /** Code ExerciseDB (CHEST, BACK, WAIST...). */
    @Id
    private String name;

    /** Libelle affiche en francais. */
    @Column(name = "label_fr", nullable = false)
    private String labelFr;

    /** Image illustrative (CDN ExerciseDB). */
    @Column(name = "image_url", columnDefinition = "text")
    private String imageUrl;

    /** Ordre d'affichage. */
    @Column(name = "sort_order", nullable = false)
    private int sortOrder;
}
