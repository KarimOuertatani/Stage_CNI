package com.fitforge.api.nutrition.repository;

import com.fitforge.api.common.enums.MealType;
import com.fitforge.api.nutrition.entity.NutritionEntry;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Acces base pour le journal alimentaire.
 */
public interface NutritionEntryRepository extends JpaRepository<NutritionEntry, UUID> {

    /** Toutes les entrees d'un adherent pour un jour donne. */
    List<NutritionEntry> findByUserIdAndConsumedOnOrderByMealType(UUID userId, LocalDate date);

    /** Entrees d'un repas precis de la journee (totaux par repas). */
    List<NutritionEntry> findByUserIdAndConsumedOnAndMealType(
            UUID userId, LocalDate date, MealType mealType);
}
