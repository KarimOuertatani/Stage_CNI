package com.fitforge.api.sleep.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fitforge.api.common.enums.SleepBand;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

/**
 * Un jour de la semaine dans l'histogramme — <b>rempli ou vide</b>.
 *
 * <h2>Pourquoi les jours sans saisie sont renvoyes quand meme</h2>
 *
 * <p>Le serveur renvoie toujours <b>sept</b> jours, meme si trois seulement ont
 * ete saisis. C'est ce qui permet a l'histogramme d'afficher des colonnes
 * creuses aux bons endroits plutot que de tasser quatre barres cote a cote.
 *
 * <p>La difference est loin d'etre cosmetique : quatre barres serrees se lisent
 * comme quatre jours consecutifs, et l'adherent croit voir une semaine complete.
 * Les trous doivent se voir — ce sont eux qui donnent envie de saisir.
 *
 * <p>Un jour vide a {@code durationMinutes} et {@code band} a {@code null},
 * et non a zero : zero voudrait dire « il n'a pas dormi ».
 */
@Schema(description = "Un jour de l'histogramme, avec ou sans nuit saisie")
public record SleepDayResponse(

        @Schema(description = "Identifiant de la nuit, null si aucune saisie")
        UUID id,

        LocalDate date,

        @Schema(description = "1 = lundi ... 7 = dimanche", example = "3")
        int dayOfWeek,

        @Schema(description = "Duree en minutes, null si la nuit n'a pas ete saisie",
                example = "450")
        Integer durationMinutes,

        @Schema(description = "Tranche de duree, null si la nuit n'a pas ete saisie")
        SleepBand band,

        @Schema(example = "23:30", type = "string")
        @JsonFormat(pattern = "HH:mm")
        LocalTime bedTime,

        @Schema(example = "07:00", type = "string")
        @JsonFormat(pattern = "HH:mm")
        LocalTime wakeTime
) {

    /** Le jour creux : la place est tenue, la donnee est absente. */
    public static SleepDayResponse empty(LocalDate date) {
        return new SleepDayResponse(
                null, date, date.getDayOfWeek().getValue(), null, null, null, null);
    }
}
