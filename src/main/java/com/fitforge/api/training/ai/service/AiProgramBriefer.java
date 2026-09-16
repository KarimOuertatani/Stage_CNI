package com.fitforge.api.training.ai.service;

import com.fitforge.api.coaching.ai.service.AiCoachProfileBriefer;
import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.common.enums.MuscleGroup;
import com.fitforge.api.training.ai.dto.GenerateProgramRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

/**
 * Le brief : ce que le modele sait de l'adherent avant d'ecrire une ligne.
 *
 * <h2>Deux sources, et elles ne disent pas la meme chose</h2>
 *
 * <ul>
 *   <li><b>Le profil</b> (deja resume par {@link AiCoachProfileBriefer}, reutilise
 *       tel quel plutot que redecrit ici) : ce que l'adherent est — age, poids,
 *       niveau, blessures declarees, sommeil, cible calorique. Ces donnees ne
 *       sont pas ressaisies : les redemander dans le questionnaire serait a la
 *       fois penible et une source de contradiction.</li>
 *   <li><b>Le questionnaire</b> : ce que l'adherent veut <b>pour ce programme</b>.
 *       C'est la que se joue la structure — nombre de seances, duree, materiel du
 *       moment, zones a prioriser, charges de reference.</li>
 * </ul>
 *
 * <p>Quand les deux se contredisent (le profil dit 3 seances par semaine, le
 * questionnaire en demande 5), <b>le questionnaire gagne</b> : c'est la reponse
 * la plus recente, donnee pour ce programme precis. La consigne systeme le dit
 * explicitement au modele, faute de quoi il tenterait une moyenne.
 *
 * <h2>Format</h2>
 *
 * <p>Des lignes courtes en francais, pas du JSON. Un modele lit mieux une fiche
 * qu'une structure de donnees, et le texte produit ici est conserve tel quel
 * dans le journal des generations : il doit rester lisible par un humain qui
 * cherche a comprendre pourquoi un programme est sorti comme ca.
 */
@Component
@RequiredArgsConstructor
public class AiProgramBriefer {

    private static final String[] DAY_NAMES = {
            "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"
    };

    private final AiCoachProfileBriefer profileBriefer;

    /**
     * Le brief complet, questionnaire d'abord.
     *
     * <p>L'ordre n'est pas indifferent : ce que l'adherent vient de repondre
     * prime sur ce que son profil dit, et un modele accorde spontanement plus
     * de poids a ce qu'il lit en premier.
     */
    public String brief(UUID userId, GenerateProgramRequest req) {
        StringBuilder sb = new StringBuilder(1024);

        sb.append("## Demande de l'adherent (prioritaire)\n\n");
        sb.append(questionnaire(req));

        String profile = profileBriefer.briefFor(userId);
        if (profile != null && !profile.isBlank()) {
            sb.append("\n## Profil enregistre de l'adherent\n\n");
            sb.append(profile).append('\n');
        }

        return sb.toString();
    }

    // ── Le questionnaire, mis en fiche ───────────────────────────────

    private String questionnaire(GenerateProgramRequest req) {
        List<String> lines = new ArrayList<>();

        lines.add("- Objectif de ce programme : " + humanize(req.goal()));
        lines.add("- Niveau en musculation : " + humanize(req.experienceLevel()));
        lines.add("- Seances par semaine : " + req.daysPerWeek()
                + " (ce nombre est un ordre, pas une suggestion)");
        lines.add("- Duree d'une seance : environ " + req.sessionMinutes() + " minutes");

        if (req.durationWeeks() != null) {
            lines.add("- Duree du programme : " + req.durationWeeks() + " semaines");
        }
        lines.add("- Lieu d'entrainement : " + humanize(req.location()));

        List<Equipment> equipment = req.equipmentOrEmpty();
        lines.add(equipment.isEmpty()
                ? "- Materiel : salle complete, tout est disponible"
                : "- Materiel disponible : " + join(equipment) + ", plus le poids de corps");

        List<Integer> days = req.preferredDaysOrEmpty();
        if (!days.isEmpty()) {
            lines.add("- Jours souhaites : " + dayNames(days));
        }

        List<MuscleGroup> focus = req.focusMusclesOrEmpty();
        if (!focus.isEmpty()) {
            lines.add("- Zones a prioriser (volume superieur aux autres) : " + join(focus));
        }

        lines.add(req.includeCardio()
                ? "- Cardio : a inclure dans le programme"
                : "- Cardio : l'adherent n'en veut pas dans ce programme");

        // ── Charges de reference ────────────────────────────────────
        // Presentees comme des maximums : c'est ce qui permet au modele de
        // calculer un pourcentage plutot que d'inventer un poids.
        List<String> lifts = new ArrayList<>();
        addLift(lifts, "developpe couche", req.benchPressKg());
        addLift(lifts, "squat", req.squatKg());
        addLift(lifts, "souleve de terre", req.deadliftKg());
        if (req.maxPullUps() != null) {
            lifts.add("tractions strictes : " + req.maxPullUps() + " repetitions");
        }
        if (!lifts.isEmpty()) {
            lines.add("- Charges de reference (maximum sur 1 repetition, sauf tractions) : "
                    + String.join(" ; ", lifts));
        } else {
            lines.add("- Charges de reference : non communiquees — ne propose donc "
                    + "aucun poids chiffre, raisonne en repetitions et en ressenti");
        }

        if (req.constraints() != null && !req.constraints().isBlank()) {
            // Le champ libre passe en dernier et se lit comme une contrainte
            // dure : c'est la seule reponse que rien d'autre ne peut exprimer.
            lines.add("- Contraintes imposees par l'adherent, a respecter absolument : "
                    + req.constraints().trim());
        }

        return String.join("\n", lines) + "\n";
    }

    // ── Mise en forme ────────────────────────────────────────────────

    private void addLift(List<String> lifts, String label, Double weight) {
        if (weight != null && weight > 0) {
            lifts.add(label + " : " + format(weight) + " kg");
        }
    }

    /** {@code PERTE_POIDS} devient « perte poids » — un libelle que le modele lit. */
    private String humanize(Enum<?> value) {
        return value == null ? null : value.name().toLowerCase(Locale.ROOT).replace('_', ' ');
    }

    private String join(List<? extends Enum<?>> values) {
        return values.stream().filter(java.util.Objects::nonNull).map(this::humanize)
                .reduce((a, b) -> a + ", " + b).orElse("");
    }

    private String dayNames(List<Integer> days) {
        List<String> names = new ArrayList<>(days.size());
        for (Integer day : days) {
            if (day != null && day >= 1 && day <= 7) {
                names.add(DAY_NAMES[day - 1]);
            }
        }
        return String.join(", ", names);
    }

    /** « 70 kg » plutot que « 70.0 kg ». */
    private String format(double value) {
        return value == Math.rint(value)
                ? String.valueOf((long) value)
                : String.valueOf(value);
    }
}
