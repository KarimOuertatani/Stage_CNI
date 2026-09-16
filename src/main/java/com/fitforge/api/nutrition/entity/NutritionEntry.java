package com.fitforge.api.nutrition.entity;

import com.fitforge.api.common.enums.MealType;
import com.fitforge.api.user.entity.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;
import java.util.UUID;

/**
 * Une ligne du journal alimentaire : un aliment/repas consomme un jour donne,
 * avec ses calories et macros. Le resume quotidien additionne ces lignes.
 *
 * <p><b>Deux modes de creation :</b>
 * <ul>
 *   <li><b>Depuis le catalogue</b> (USDA) : l'adherent choisit un aliment et
 *       une quantite en grammes ; les macros sont calculees au prorata par le
 *       serveur ({@code macro = macroPer100g * grammes / 100}). {@link #foodItem}
 *       reference l'aliment source.</li>
 *   <li><b>Saisie manuelle</b> : l'adherent tape lui-meme les valeurs (repas
 *       maison, restaurant...). {@link #foodItem} reste {@code null}.</li>
 * </ul>
 *
 * <p><b>Important :</b> les macros sont <b>figees a l'enregistrement</b>, meme
 * quand l'entree vient du catalogue. L'historique reste donc exact si un
 * {@code FoodItem} est corrige plus tard.
 */
@Entity
@Table(name = "nutrition_entries")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NutritionEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Adherent proprietaire de l'entree (LAZY). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** Jour de consommation. */
    @Column(nullable = false)
    private LocalDate consumedOn;

    @Enumerated(EnumType.STRING)
    private MealType mealType;      // PETIT_DEJ, DEJEUNER, DINER, COLLATION

    /**
     * Aliment du catalogue dont provient cette entree (null = saisie manuelle).
     * Sert a reafficher la provenance et a proposer un « re-ajouter ».
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "food_item_id")
    private FoodItem foodItem;

    private String foodName;
    private Double quantityGrams;
    private Integer calories;
    private Double proteinG;        // proteines (g)
    private Double carbsG;          // glucides (g)
    private Double fatG;            // lipides (g)
    private Double fiberG;          // fibres (g) - souvent absentes cote USDA
}
