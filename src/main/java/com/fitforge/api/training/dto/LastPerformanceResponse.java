package com.fitforge.api.training.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.util.List;

/**
 * Ce que l'adherent a fait la DERNIERE FOIS sur un exercice donne.
 *
 * <p>C'est la seule information qui manque au moment de charger la barre.
 * Sans elle, l'ecran de saisie propose les memes 10 repetitions a 20 kg a tout
 * le monde, et l'adherent doit se souvenir — ou aller fouiller l'historique.
 * Avec elle, il reprend exactement ou il s'etait arrete, et la progression
 * devient visible seance apres seance.
 */
@Schema(description = "Derniere performance realisee sur un exercice")
public record LastPerformanceResponse(
        LocalDate performedOn,
        /** Nombre de jours ecoules — evite au client de recalculer une date. */
        long daysAgo,
        List<Set> sets,
        /** Charge la plus lourde de la seance, sur une serie terminee. */
        Double bestWeightKg,
        /** Volume total (somme reps x charge) de la seance sur cet exercice. */
        double totalVolumeKg
) {

    /** Une serie realisee (numero, repetitions, charge). */
    public record Set(Integer setNumber, Integer reps, Double weightKg) {
    }
}
