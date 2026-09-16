package com.fitforge.api.training.service;

import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.common.enums.ExperienceLevel;
import com.fitforge.api.training.entity.Exercise;

import java.util.List;
import java.util.Locale;

/**
 * Determine le NIVEAU d'un exercice (debutant / intermediaire / avance).
 *
 * <p><b>Pourquoi une heuristique ?</b> ExerciseDB ne fournit aucun champ de
 * difficulte. Faute de mieux, l'application deduisait le niveau du seul
 * materiel, cote client : « barre = avance ». C'est faux une fois sur deux — un
 * curl a la barre est un exercice de debutant, un arrache a la barre est un
 * mouvement olympique.
 *
 * <p><b>Pourquoi un score et pas une cascade de {@code if} ?</b> Une premiere
 * version prenait la premiere regle qui matchait, et se trompait exactement la
 * ou les signaux se contredisent : « Seated Single Leg Hamstring Stretch »
 * ressortait AVANCE (« single leg ») alors que c'est un etirement, et « Calf
 * Raise from Deficit with Chair Supported » ignorait son appui. Les signaux
 * doivent se COMPOSER, pas s'exclure : un mouvement technique rendu plus facile
 * par un appui est plus facile qu'un mouvement technique.
 *
 * <p><b>Le modele.</b> Un score sur trois crans (0 debutant, 1 intermediaire,
 * 2 avance) :
 * <ol>
 *   <li><b>Court-circuit.</b> Un etirement, une mobilisation articulaire ou une
 *       posture de yoga est accessible quoi qu'il arrive : niveau debutant,
 *       sans discussion. C'est la seule regle qui court-circuite les autres,
 *       parce qu'aucun autre signal ne peut la contredire.</li>
 *   <li><b>Base : le materiel.</b> Guide-t-il le mouvement ? Machine et poids
 *       du corps partent a 0, charge libre a 1, kettlebell a 2.</li>
 *   <li><b>Modificateurs : le nom.</b> Le signal le plus riche, surtout ici ou
 *       les trois quarts du catalogue sont au poids du corps et ou le materiel
 *       ne distingue donc plus rien. Chaque famille compte UNE fois, pour
 *       qu'un nom a rallonge ne gonfle pas son score a coups de synonymes.</li>
 * </ol>
 *
 * <p>La regle vit ici, en un seul endroit, et sert a la fois l'import de
 * nouveaux exercices ({@code ExerciseImportService}) et le remplissage des
 * exercices deja en base ({@link ExerciseDifficultyBackfiller}). C'est
 * volontairement du Java et non un {@code CASE} SQL dans la migration : une
 * regle ecrite a deux endroits finit par diverger.
 */
public final class ExerciseDifficultyRules {

    private ExerciseDifficultyRules() {
    }

    /**
     * Ce dont on est sur qu'un debutant peut le faire : etirements, mobilite
     * articulaire, postures, rotations de nuque et de poignet.
     *
     * <p>Ces mots court-circuitent le reste du calcul. Sans eux, « Seated
     * Single Leg Hamstring Stretch » decrocherait le bonus « unilateral » et
     * ressortirait avance — un etirement des ischio-jambiers assis.
     */
    private static final List<String> ALWAYS_BEGINNER = List.of(
            "stretch", "articulations", "mobility", "yoga", "pose",
            "circles", "circling", "neck", "wrist", "toe touching",
            // La corde a sauter et le jumping jack contiennent « jump » sans
            // rien avoir de pliometrique : ce sont des echauffements.
            "warm up", "jumping jack", "jump rope");

    /**
     * Mouvements dont la technique s'apprend, et dont l'echec fait mal :
     * halterophilie, gymnastique de force, unilateral profond, explosif.
     */
    private static final List<String> ELITE = List.of(
            // Halterophilie
            "snatch", "clean and jerk", "power clean", "hang clean", "jerk",
            "overhead squat", "zercher", "behind the neck",
            // Gymnastique de force
            "handstand", "hand stand", "muscle up", "front lever", "back lever",
            "human flag", "iron cross", "l sit", "l pull up", "commando",
            // Unilateral profond
            "pistol", "sissy", "shrimp squat", "single leg squat",
            "one leg squat",
            // Explosif / amplitude majoree
            "clap", "depth jump", "deficit");

    /**
     * Mouvements qui demandent deja une base : tractions, dips, gainage
     * dynamique, fentes chargees, sauts.
     *
     * <p>C'est la famille qui remonte le poids du corps hors de « debutant ».
     * Une traction et une pompe partagent le meme materiel — aucun — mais pas
     * le meme public.
     */
    private static final List<String> DEMANDING = List.of(
            "pull up", "chin up", "pullup", "dip", "burpee", "hanging",
            "inverted", "pike push", "decline push", "diamond", "close grip",
            "wide grip", "shoulder tap", "archer", "cobra push",
            "bulgarian", "split squat", "russian twist", "v up",
            "jump", "scissor", "flutter", "hyperextension",
            "suspended", "suspension", "good morning", "thruster",
            "deadlift", "single leg", "one leg", "walking lunge",
            "explosive", "sprint", "plyo",
            // « squat thrust » et non « thrust » tout court : le motif large
            // attrapait le hip thrust, qui est un mouvement grand public.
            "squat thrust",
            // Les exercices seed sont en francais : sans ces deux mots, une
            // traction ressortait « debutant » — elle n'a pourtant ni materiel
            // a guider le mouvement, ni public debutant.
            "traction", "souleve de terre");

    /**
     * Marques de REGRESSION : le mouvement a ete rendu plus facile (aide,
     * appui, amplitude reduite, position au sol ou assise).
     */
    private static final List<String> REGRESSION = List.of(
            "assisted", "supported", "with support", "on knees", "kneeling",
            "wall", "incline push", "chair", "towel", "partial", "beginner",
            "static", "isometric", "seated", "lying", "on forearms",
            "bent knee", "band");

    /** Niveau d'un exercice deja construit. Ne renvoie jamais {@code null}. */
    public static ExperienceLevel of(Exercise exercise) {
        return of(exercise.getName(), exercise.getExerciseType(), exercise.getEquipment());
    }

    /**
     * Niveau a partir des trois signaux bruts.
     *
     * @param name      nom de l'exercice (anglais pour ExerciseDB, francais pour les seed)
     * @param type      type ExerciseDB (STRENGTH, STRETCHING, PLYOMETRICS...), peut etre null
     * @param equipment materiel requis, peut etre null
     */
    public static ExperienceLevel of(String name, String type, Equipment equipment) {
        String normalized = normalize(name);
        String upperType = type == null ? "" : type.toUpperCase(Locale.ROOT);

        // 1. Court-circuit : rien ne rend un etirement difficile.
        if (upperType.contains("STRETCH") || upperType.contains("YOGA")
                || containsAny(normalized, ALWAYS_BEGINNER)) {
            return ExperienceLevel.DEBUTANT;
        }

        // 2. Base : le materiel guide-t-il le mouvement ?
        int score = baseScore(equipment);

        // La pliometrie et l'halterophilie sont des disciplines a part entiere :
        // l'impact au sol et la vitesse d'execution ne s'improvisent pas.
        if (upperType.contains("PLYO") || upperType.contains("WEIGHTLIFTING")) {
            score += 1;
        }

        // 3. Le nom. Chaque famille compte une seule fois.
        if (containsAny(normalized, ELITE)) {
            score += 2;
        }
        if (containsAny(normalized, DEMANDING)) {
            score += 1;
        }
        if (containsAny(normalized, REGRESSION)) {
            score -= 1;
        }

        if (score <= 0) {
            return ExperienceLevel.DEBUTANT;
        }
        return score == 1 ? ExperienceLevel.INTERMEDIAIRE : ExperienceLevel.AVANCE;
    }

    /** Machine et poids du corps a 0, charge libre a 1, kettlebell a 2. */
    private static int baseScore(Equipment equipment) {
        if (equipment == null) {
            return 1;
        }
        return switch (equipment) {
            // La machine impose la trajectoire, l'elastique pardonne la charge,
            // le poids du corps ne peut pas etre surcharge par erreur.
            case MACHINE, ELASTIQUE, POIDS_CORPS -> 0;
            // Charge libre : la trajectoire est a tenir soi-meme.
            case HALTERE, POULIE, BARRE -> 1;
            // Balistique par nature : une trajectoire ratee part loin.
            case KETTLEBELL -> 2;
        };
    }

    /**
     * Minuscules, sans ponctuation, espaces normalises.
     *
     * <p>« Wide Grip Pull-Up » devient « wide grip pull up » : les motifs
     * s'ecrivent alors une seule fois, au lieu de devoir prevoir « pull-up »,
     * « pullup » et « Pull Up » separement.
     */
    private static String normalize(String value) {
        if (value == null) {
            return "";
        }
        StringBuilder sb = new StringBuilder(value.length());
        for (char c : value.toLowerCase(Locale.ROOT).toCharArray()) {
            sb.append(Character.isLetterOrDigit(c) ? c : ' ');
        }
        return sb.toString().replaceAll("\\s+", " ").trim();
    }

    private static boolean containsAny(String haystack, List<String> patterns) {
        for (String pattern : patterns) {
            if (haystack.contains(pattern)) {
                return true;
            }
        }
        return false;
    }
}
