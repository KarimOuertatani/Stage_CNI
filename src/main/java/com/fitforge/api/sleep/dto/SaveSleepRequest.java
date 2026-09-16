package com.fitforge.api.sleep.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.time.LocalTime;

/**
 * Ce que l'adherent saisit : a quelle heure il s'est couche, a quelle heure il
 * s'est leve. Rien d'autre.
 *
 * <h2>Pourquoi pas la duree directement</h2>
 *
 * <p>Parce que personne ne connait la duree de sa nuit : on connait ses heures.
 * Demander « combien de temps as-tu dormi ? » oblige a faire la soustraction de
 * tete — et a la faire faux une fois sur trois quand la nuit passe minuit.
 * Deux heures a choisir, c'est un geste ; une duree a calculer, c'est un effort.
 *
 * <p>Et la duree deduite de deux heures reste comparable d'un jour a l'autre,
 * la ou une duree saisie a la main s'arrondit toujours au meme « 8 heures ».
 *
 * <h2>La date est facultative</h2>
 *
 * <p>Absente, c'est <b>aujourd'hui</b> — le cas de tous les jours, puisque la
 * saisie se fait au reveil. Elle n'existe que pour rattraper une nuit oubliee.
 */
@Schema(description = "Saisie d'une nuit de sommeil")
public record SaveSleepRequest(

        @Schema(description = """
                Jour du REVEIL. Absent = aujourd'hui. Une nuit etant a cheval
                sur deux jours, c'est le reveil qui la date : deux personnes
                couchees a 23 h et a 1 h du matin parlent de la meme nuit.""",
                example = "2026-08-01")
        LocalDate sleepDate,

        @Schema(description = "Heure de coucher", example = "23:30", type = "string")
        @NotNull
        @JsonFormat(pattern = "HH:mm")
        LocalTime bedTime,

        @Schema(description = "Heure de lever", example = "07:00", type = "string")
        @NotNull
        @JsonFormat(pattern = "HH:mm")
        LocalTime wakeTime
) {
}
