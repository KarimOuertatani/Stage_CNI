package com.fitforge.api.sleep.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.util.List;

/**
 * Une semaine de sommeil : l'histogramme, le score, et ce qu'il faut en retenir.
 *
 * <p>Tout est calcule <b>cote serveur</b> — moyenne, score, conseils, ecart du
 * week-end. L'application ne fait qu'afficher.
 *
 * <p>Ce n'est pas une preference d'architecture. Ces valeurs sont aussi lues
 * par d'autres chemins (le profil, le coach IA qui recoit la moyenne de
 * sommeil) : les recalculer cote Flutter garantirait qu'un jour les deux ne
 * diront plus la meme chose, et personne ne saurait laquelle croire.
 */
@Schema(description = "Semaine de sommeil : histogramme, moyenne, score et conseils")
public record SleepWeekResponse(

        @Schema(description = "Lundi de la semaine", example = "2026-07-27")
        LocalDate weekStart,

        @Schema(description = "Dimanche de la semaine", example = "2026-08-02")
        LocalDate weekEnd,

        @Schema(description = "Toujours 7 entrees, du lundi au dimanche. "
                + "Les jours sans saisie sont presents avec une duree nulle.")
        List<SleepDayResponse> days,

        @Schema(description = "Nombre de nuits reellement saisies", example = "5")
        int nightsLogged,

        @Schema(description = "Duree moyenne des nuits saisies, en minutes. "
                + "Null si aucune nuit.", example = "441")
        Integer averageMinutes,

        @Schema(description = """
                Note 0-100 : duree moyenne (70 points) et regularite des heures
                de coucher (30 points). En dessous de trois nuits, la regularite
                n'est pas mesurable et la duree occupe les 100 points.
                Null si aucune nuit.""",
                example = "78")
        Integer score,

        @Schema(description = "Titre commentant le score", example = "Bonne semaine")
        String headline,

        @Schema(description = """
                Ecart entre les nuits de week-end et celles de semaine, en
                minutes. Un ecart important trahit une dette accumulee en
                semaine et rattrapee le week-end — un motif invisible sur la
                seule moyenne. Null si l'un des deux groupes est vide.""",
                example = "62")
        Integer weekendCatchUpMinutes,

        @Schema(description = "Deux a trois conseils sur la semaine ecoulee")
        List<String> tips,

        @Schema(description = "Vrai si c'est la semaine en cours — l'application "
                + "s'en sert pour interdire la navigation vers le futur")
        boolean currentWeek
) {
}
