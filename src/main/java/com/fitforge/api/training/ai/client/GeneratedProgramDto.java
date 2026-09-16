package com.fitforge.api.training.ai.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import java.util.List;

/**
 * Ce que le modele renvoie : un programme, en numeros de catalogue.
 *
 * <h2>Pourquoi {@code ref} est un entier et pas un nom d'exercice</h2>
 *
 * <p>Parce qu'un nom libre ne se rattache a rien (voir
 * {@code ExerciseCatalogBriefer}). Le modele choisit dans la liste numerotee
 * qu'on lui a donnee ; un numero valide designe forcement un exercice reel de
 * notre referentiel, avec sa video et ses instructions. C'est ce qui rend
 * impossible un programme contenant un exercice inexistant.
 *
 * <h2>L'ordre des champs compte</h2>
 *
 * <p>{@code rationale} vient <b>avant</b> {@code sessions}. Un modele genere de
 * gauche a droite : en lui faisant expliquer sa logique d'abord, on l'oblige a
 * choisir un decoupage et un volume <i>avant</i> de placer le premier exercice.
 * Dans l'autre sens, il justifierait apres coup ce qu'il vient d'ecrire — et
 * l'explication serait aussi decorative que le programme serait arbitraire.
 *
 * <p>Aucune valeur n'est prise pour argent comptant : tout est borne et
 * verifie par {@code AiProgramService} avant d'atteindre la base.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record GeneratedProgramDto(
        String title,
        String description,
        String rationale,
        Integer durationWeeks,
        List<Session> sessions
) {

    /** Vrai si la reponse contient de quoi construire un programme. */
    public boolean isUsable() {
        return title != null && !title.isBlank()
                && sessions != null && !sessions.isEmpty();
    }

    /**
     * Une seance-type.
     *
     * @param dayOfWeek 1 = lundi ... 7 = dimanche, ou {@code null} si le modele
     *                  n'a pas eu de jours imposes
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Session(
            String title,
            Integer dayOfWeek,
            List<PlacedExercise> exercises
    ) {
    }

    /**
     * Un exercice place dans une seance.
     *
     * @param ref        numero dans le catalogue soumis au modele
     * @param weightKg   charge cible, {@code null} si aucune charge de reference
     *                   n'a ete communiquee (proposer un poids invente serait
     *                   pire que ne rien proposer)
     * @param notes      la consigne de coach : tempo, repetitions en reserve,
     *                   adaptation en cas de gene
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record PlacedExercise(
            Integer ref,
            Integer sets,
            Integer reps,
            Integer restSeconds,
            Double weightKg,
            String notes
    ) {
    }
}
