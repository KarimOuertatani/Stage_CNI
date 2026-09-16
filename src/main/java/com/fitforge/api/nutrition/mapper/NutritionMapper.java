package com.fitforge.api.nutrition.mapper;

import com.fitforge.api.nutrition.dto.NutritionEntryResponse;
import com.fitforge.api.nutrition.entity.NutritionEntry;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

/**
 * Mapping MapStruct pour le journal alimentaire.
 */
@Mapper(componentModel = "spring")
public interface NutritionMapper {

    /**
     * On n'expose que l'<b>id</b> de l'aliment source, pas l'entite complete.
     * Lire {@code foodItem.id} n'initialise pas le proxy LAZY (Hibernate connait
     * deja l'identifiant) : aucun SELECT supplementaire, donc pas de N+1.
     */
    @Mapping(target = "foodItemId", source = "foodItem.id")
    NutritionEntryResponse toResponse(NutritionEntry entry);
}
