package com.fitforge.api.score.mapper;

import com.fitforge.api.score.dto.TrainingScoreResponse;
import com.fitforge.api.score.entity.TrainingScore;
import org.mapstruct.Mapper;

/**
 * Mapping MapStruct pour le score d'entrainement.
 */
@Mapper(componentModel = "spring")
public interface TrainingScoreMapper {

    TrainingScoreResponse toResponse(TrainingScore score);
}
