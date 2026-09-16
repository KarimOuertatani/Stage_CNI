package com.fitforge.api.training.mapper;

import com.fitforge.api.training.dto.ProgramResponse;
import com.fitforge.api.training.dto.SessionExerciseResponse;
import com.fitforge.api.training.dto.SessionResponse;
import com.fitforge.api.training.entity.SessionExercise;
import com.fitforge.api.training.entity.WorkoutProgram;
import com.fitforge.api.training.entity.WorkoutSession;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

/**
 * Mapping MapStruct du programme complet (programme -> seances -> exercices places).
 * uses = ExerciseMapper : pour transformer l'Exercise imbrique en ExerciseResponse.
 */
@Mapper(componentModel = "spring", uses = ExerciseMapper.class)
public interface ProgramMapper {

    /**
     * Programme -> reponse. Le champ booleen "isTemplate" est mappe explicitement
     * car le getter Lombok isTemplate() est vu par MapStruct comme la propriete
     * "template" (il retire le prefixe "is").
     */
    @Mapping(target = "isTemplate", source = "template")
    @Mapping(target = "createdById", source = "createdBy.id")
    @Mapping(target = "createdByName", source = "createdBy.fullName")
    ProgramResponse toResponse(WorkoutProgram program);

    SessionResponse toSessionResponse(WorkoutSession session);

    SessionExerciseResponse toSessionExerciseResponse(SessionExercise sessionExercise);
}
