package com.fitforge.api.training.mapper;

import com.fitforge.api.training.dto.SetLogResponse;
import com.fitforge.api.training.dto.WorkoutLogResponse;
import com.fitforge.api.training.entity.SetLog;
import com.fitforge.api.training.entity.WorkoutLog;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

/**
 * Mapping MapStruct des seances effectuees (log -> series).
 * uses = ExerciseMapper : pour le detail de l'exercice de chaque serie.
 */
@Mapper(componentModel = "spring", uses = ExerciseMapper.class)
public interface WorkoutLogMapper {

    /** log -> reponse. sessionId provient de la seance-type liee (peut etre null). */
    @Mapping(target = "sessionId", source = "session.id")
    WorkoutLogResponse toResponse(WorkoutLog log);

    SetLogResponse toSetLogResponse(SetLog setLog);
}
