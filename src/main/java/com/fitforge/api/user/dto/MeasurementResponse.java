package com.fitforge.api.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.util.UUID;

/**
 * Une pesee/mensuration renvoyee a Flutter (pour tracer les courbes).
 */
@Schema(description = "Pesee/mensuration historisee")
public record MeasurementResponse(
        UUID id,
        LocalDate measuredOn,
        Double weightKg,
        Double bodyFatPercent,
        Double waistCm,
        Double chestCm,
        Double armCm,
        Double thighCm
) {}
