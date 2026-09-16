package com.fitforge.api.coaching.ai.service;

import com.fitforge.api.common.enums.DietaryPreference;
import com.fitforge.api.user.entity.UserProfile;
import com.fitforge.api.user.repository.UserProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

/**
 * Resume le profil d'un adherent en quelques lignes, pour le coach IA.
 *
 * <h2>Pourquoi c'est la piece qui fait la difference</h2>
 *
 * <p>Sans profil, un coach IA repond ce qu'un moteur de recherche repondrait :
 * « fais 3 series de 10 ». Avec le profil, il sait que l'adherent est debutant,
 * s'entraine a la maison avec des elastiques, vise une perte de poids et a le
 * genou fragile — et la reponse devient utilisable. C'est toute la difference
 * entre un chatbot et un coach.
 *
 * <h2>Ce qui est envoye, et ce qui ne l'est pas</h2>
 *
 * <p>On envoie ce qui <b>change une reponse d'entrainement ou de nutrition</b> :
 * objectif, niveau, lieu, materiel, blessures connues, regime, allergies,
 * cible calorique. On n'envoie <b>pas</b> le nom, l'email, la date de naissance
 * exacte ni les notes medicales libres : ces donnees n'ameliorent aucun conseil
 * et n'ont donc rien a faire chez un tiers.
 *
 * <p>Les blessures connues, elles, sont envoyees a dessein : ce sont
 * precisement celles qu'un conseil d'exercice ne doit pas aggraver.
 *
 * <p><b>Format</b> : des lignes courtes, en francais, pas du JSON. Un modele de
 * langage lit mieux une fiche qu'une structure de donnees, et cela limite le
 * nombre de jetons consommes a chaque message.
 */
@Component
@RequiredArgsConstructor
public class AiCoachProfileBriefer {

    /** Nombre maximal de blessures citees — au-dela, la fiche devient illisible. */
    private static final int MAX_INJURIES = 5;
    /** Idem pour les allergies. */
    private static final int MAX_ALLERGIES = 5;

    private final UserProfileRepository profileRepo;

    /**
     * Fiche de l'adherent, ou {@code null} s'il n'a pas de profil exploitable.
     *
     * <p>Renvoyer {@code null} plutot qu'une fiche vide est volontaire : une
     * section « Profil » suivie de rien ferait croire au modele que ces
     * informations ont ete recherchees et n'existent pas, alors qu'elles n'ont
     * simplement jamais ete saisies. Il vaut mieux qu'il pose la question.
     */
    @Transactional(readOnly = true)
    public String briefFor(UUID userId) {
        UserProfile profile = profileRepo.findByUserId(userId).orElse(null);
        if (profile == null) {
            return null;
        }

        List<String> lines = new ArrayList<>();

        add(lines, "Objectif", humanize(profile.getGoal()));
        add(lines, "Niveau", humanize(profile.getExperienceLevel()));
        add(lines, "Lieu d'entrainement", humanize(profile.getPreferredLocation()));

        if (profile.getWeeklyWorkoutTarget() != null) {
            lines.add("- Seances visees : " + profile.getWeeklyWorkoutTarget() + " par semaine");
        }
        if (profile.getAge() != null) {
            lines.add("- Age : " + profile.getAge() + " ans");
        }
        if (profile.getCurrentWeightKg() != null) {
            String weight = "- Poids actuel : " + format(profile.getCurrentWeightKg()) + " kg";
            if (profile.getTargetWeightKg() != null) {
                weight += " (vise " + format(profile.getTargetWeightKg()) + " kg)";
            }
            lines.add(weight);
        }
        if (profile.getHeightCm() != null) {
            lines.add("- Taille : " + format(profile.getHeightCm()) + " cm");
        }
        if (profile.getDailyCalorieTarget() != null) {
            lines.add("- Cible calorique : " + profile.getDailyCalorieTarget() + " kcal/jour");
        } else if (profile.getTdee() != null) {
            lines.add("- Depense estimee : " + profile.getTdee() + " kcal/jour");
        }

        List<String> equipment = humanizeAll(profile.getAvailableEquipment());
        if (!equipment.isEmpty()) {
            lines.add("- Materiel disponible : " + String.join(", ", equipment));
        }

        // Les blessures passent en dernier mais sont les plus importantes : on
        // les annonce comme une contrainte, pas comme une information.
        List<String> injuries = trim(profile.getInjuries(), MAX_INJURIES);
        if (!injuries.isEmpty()) {
            lines.add("- Blessures ou zones fragiles a menager : "
                    + String.join(", ", injuries));
        }

        DietaryPreference diet = profile.getDietaryPreference();
        if (diet != null && diet != DietaryPreference.AUCUNE) {
            lines.add("- Regime alimentaire : " + humanize(diet));
        }
        List<String> allergies = trim(profile.getAllergies(), MAX_ALLERGIES);
        if (!allergies.isEmpty()) {
            lines.add("- Allergies : " + String.join(", ", allergies));
        }

        if (profile.getAverageSleepHours() != null) {
            lines.add("- Sommeil moyen : " + format(profile.getAverageSleepHours()) + " h/nuit");
        }

        return lines.isEmpty() ? null : String.join("\n", lines);
    }

    // ── Mise en forme ────────────────────────────────────────────────

    private void add(List<String> lines, String label, String value) {
        if (value != null) {
            lines.add("- " + label + " : " + value);
        }
    }

    /**
     * Enumeration -&gt; libelle lisible.
     *
     * <p>{@code PERTE_POIDS} devient « perte poids ». On ne construit pas de
     * table de traduction : le modele comprend parfaitement ces libelles, et une
     * table serait un fichier de plus a maintenir en phase avec les enums.
     */
    private String humanize(Enum<?> value) {
        return value == null
                ? null
                : value.name().toLowerCase(Locale.ROOT).replace('_', ' ');
    }

    private List<String> humanizeAll(List<? extends Enum<?>> values) {
        if (values == null) {
            return List.of();
        }
        return values.stream().filter(java.util.Objects::nonNull).map(this::humanize).toList();
    }

    /** Entrees non vides, plafonnees et nettoyees. */
    private List<String> trim(List<String> values, int max) {
        if (values == null) {
            return List.of();
        }
        return values.stream()
                .filter(v -> v != null && !v.isBlank())
                .map(String::trim)
                .limit(max)
                .toList();
    }

    /** Nombre sans decimale inutile : « 72 kg » plutot que « 72.0 kg ». */
    private String format(double value) {
        return value == Math.rint(value)
                ? String.valueOf((long) value)
                : String.valueOf(value);
    }
}
