package com.fitforge.api.training.mapper;

import com.fitforge.api.training.dto.ExerciseResponse;
import com.fitforge.api.training.entity.Exercise;
import org.mapstruct.Mapper;

/**
 * Mapping MapStruct pour le referentiel d'exercices.
 */
@Mapper(componentModel = "spring")
public interface ExerciseMapper {

    ExerciseResponse toResponse(Exercise exercise);
}
