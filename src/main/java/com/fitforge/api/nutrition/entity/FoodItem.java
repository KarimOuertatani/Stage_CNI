package com.fitforge.api.nutrition.entity;

import com.fitforge.api.common.enums.FoodSource;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

/**
 * Aliment du catalogue local — <b>cache permanent</b> des donnees USDA
 * FoodData Central (ou aliment personnalise saisi par un adherent).
 *
 * <p><b>Pourquoi ce cache ?</b> Une fois qu'un aliment a ete recupere depuis
 * USDA, il est stocke ici definitivement : on ne rappelle JAMAIS l'API externe
 * pour cet aliment. Cela construit progressivement une base d'aliments locale,
 * reduit la latence de l'ajout d'un repas, et protege du quota USDA
 * (1000 requetes/heure).
 *
 * <p><b>Convention :</b> toutes les valeurs nutritionnelles sont exprimees
 * <b>pour 100 g</b>, comme le fait USDA. Le calcul au prorata de la quantite
 * reellement consommee est fait a l'enregistrement du repas
 * (voir {@code NutritionService}).
 */
@Entity
@Table(name = "food_items", indexes = {
        @Index(name = "idx_food_items_name", columnList = "name"),
        @Index(name = "idx_food_items_name_fr", columnList = "name_fr"),
        @Index(name = "idx_food_items_off_code", columnList = "off_code")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FoodItem {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /**
     * Libelle d'origine : description USDA (en anglais), ou nom saisi tel quel
     * pour un aliment CUSTOM. Conserve meme apres traduction, ce qui permet de
     * regenerer {@link #nameFr} apres enrichissement du lexique.
     */
    @Column(nullable = false)
    private String name;

    /**
     * Libelle <b>francais</b> affiche a l'adherent, traduit a l'import depuis
     * le lexique culinaire (voir {@code FoodLexicon}).
     *
     * <p>{@code null} pour les aliments importes avant la mise en place de la
     * traduction : ils sont alors traduits a la volee a l'affichage, et la
     * valeur est rattrapee en base au premier usage.
     */
    @Column(name = "name_fr", length = 512)
    private String nameFr;

    /** Marque / fabricant (renseigne par USDA pour les aliments de marque). */
    private String brand;

    /**
     * Identifiant USDA FoodData Central. <b>Unique</b> : c'est la cle de
     * deduplication du cache. {@code null} pour un aliment CUSTOM.
     */
    @Column(name = "usda_fdc_id", unique = true)
    private Long usdaFdcId;

    /**
     * Code-barres <b>Open Food Facts</b> (GTIN / EAN). <b>Unique</b> : c'est la
     * cle de deduplication du cache pour les produits emballes, exactement
     * comme {@link #usdaFdcId} l'est pour les aliments generiques.
     *
     * <p>{@code null} pour un aliment USDA ou CUSTOM. Un aliment ne porte
     * jamais les deux identifiants : il vient d'une source ou de l'autre.
     *
     * <p>Type texte et non numerique : un GTIN peut commencer par des zeros
     * significatifs, qu'un entier detruirait.
     */
    @Column(name = "off_code", length = 64, unique = true)
    private String offCode;

    /** Type de jeu de donnees USDA (Foundation, SR Legacy, Branded...). */
    @Column(name = "data_type", length = 32)
    private String dataType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private FoodSource source = FoodSource.USDA;

    // ── Valeurs nutritionnelles POUR 100 g ────────────────────────────

    @Column(name = "calories_per100g")
    private Double caloriesPer100g;

    @Column(name = "protein_per100g")
    private Double proteinPer100g;

    @Column(name = "carbs_per100g")
    private Double carbsPer100g;

    @Column(name = "fat_per100g")
    private Double fatPer100g;

    /** Fibres — souvent absentes des donnees USDA, donc nullable. */
    @Column(name = "fiber_per100g")
    private Double fiberPer100g;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
