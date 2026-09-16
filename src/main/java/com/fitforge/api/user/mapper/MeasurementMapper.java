package com.fitforge.api.user.mapper;

import com.fitforge.api.user.dto.MeasurementResponse;
import com.fitforge.api.user.entity.BodyMeasurement;
import org.mapstruct.Mapper;

/**
 * Mapping MapStruct pour l'historique des mensurations.
 */
@Mapper(componentModel = "spring")
public interface MeasurementMapper {

    /** Entite -> reponse (les champs portent le meme nom). */
    MeasurementResponse toResponse(BodyMeasurement measurement);
}
