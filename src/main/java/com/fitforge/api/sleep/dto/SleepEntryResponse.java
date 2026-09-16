package com.fitforge.api.sleep.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fitforge.api.common.enums.SleepBand;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

/**
 * Une nuit, telle que l'application l'affiche.
 *
 * <p>Elle porte la <b>tranche</b> et le <b>conseil</b> en plus des heures
 * saisies. Ce n'est pas de la commodite : c'est ce qui garantit qu'une barre
 * verte ne peut pas accompagner un texte parlant de nuit trop courte. La regle
 * est ecrite une fois, cote serveur ({@code SleepAdvisor}), et les deux
 * informations voyagent ensemble.
 */
@Schema(description = "Une nuit de sommeil, avec sa tranche et son conseil")
public record SleepEntryResponse(

        UUID id,

        @Schema(description = "Jour du reveil", example = "2026-08-01")
        LocalDate sleepDate,

        @Schema(example = "23:30", type = "string")
        @JsonFormat(pattern = "HH:mm")
        LocalTime bedTime,

        @Schema(example = "07:00", type = "string")
        @JsonFormat(pattern = "HH:mm")
        LocalTime wakeTime,

        @Schema(description = "Duree effective, passage de minuit compris", example = "450")
        int durationMinutes,

        @Schema(description = "Tranche de duree — pilote la couleur et le ton du conseil")
        SleepBand band,

        @Schema(description = "Titre court", example = "Nuit ideale")
        String headline,

        @Schema(description = "Le conseil du coach, rattache a l'entrainement")
        String advice
) {
}
