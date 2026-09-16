package com.fitforge.api.training.importer;

import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.common.enums.MuscleGroup;

import java.util.List;

/**
 * Projection des valeurs textuelles ExerciseDB (anglais) vers nos enums
 * {@link MuscleGroup} / {@link Equipment}, utilises pour le filtrage.
 *
 * <p>Best-effort : ce qui n'est pas mappable renvoie {@code null} (les colonnes
 * sont nullable). Le libelle brut ExerciseDB reste stocke a cote (body_part,
 * target_muscles...) pour l'affichage detaille cote app.
 */
final class ExerciseDbMapping {

    private ExerciseDbMapping() {
    }

    /**
     * Groupe musculaire principal. On privilegie le muscle cible (plus precis),
     * avec repli sur la partie du corps, puis sur le type d'exercice (cardio).
     */
    static MuscleGroup toMuscleGroup(List<String> targetMuscles,
                                     List<String> bodyParts,
                                     String exerciseType) {
        String target = first(targetMuscles);
        MuscleGroup fromMuscle = muscleFromTarget(target);
        if (fromMuscle != null) {
            return fromMuscle;
        }
        MuscleGroup fromBody = muscleFromBodyPart(first(bodyParts), target);
        if (fromBody != null) {
            return fromBody;
        }
        if (exerciseType != null) {
            String t = exerciseType.toUpperCase();
            if (t.contains("CARDIO") || t.contains("AEROBIC")) {
                return MuscleGroup.CARDIO;
            }
        }
        return null;
    }

    private static MuscleGroup muscleFromTarget(String muscle) {
        if (muscle == null) {
            return null;
        }
        String m = muscle.toUpperCase();
        if (m.contains("PECTORAL")) return MuscleGroup.PECTORAUX;
        if (m.contains("LATISSIMUS") || m.contains("TRAPEZIUS") || m.contains("RHOMBOID")
                || m.contains("TERES") || m.contains("INFRASPINATUS")
                || m.contains("ERECTOR SPINAE") || m.contains("LAT ")) return MuscleGroup.DOS;
        if (m.contains("BICEPS BRACHII") || m.contains("BRACHIALIS")
                || m.contains("BRACHIORADIALIS")) return MuscleGroup.BICEPS;
        if (m.contains("TRICEPS")) return MuscleGroup.TRICEPS;
        if (m.contains("DELTOID")) return MuscleGroup.EPAULES;
        if (m.contains("GLUTEUS") || m.contains("GLUTE")) return MuscleGroup.FESSIERS;
        if (m.contains("QUADRICEPS") || m.contains("HAMSTRING") || m.contains("ADDUCTOR")
                || m.contains("ABDUCTOR") || m.contains("SARTORIUS")
                || m.contains("PECTINEUS")) return MuscleGroup.JAMBES;
        if (m.contains("GASTROCNEMIUS") || m.contains("SOLEUS")
                || m.contains("CALV") || m.contains("CALF")) return MuscleGroup.MOLLETS;
        if (m.contains("ABDOMIN") || m.contains("OBLIQUE") || m.contains("SERRATUS")
                || m.contains("CORE")) return MuscleGroup.ABDOS;
        return null;
    }

    private static MuscleGroup muscleFromBodyPart(String bodyPart, String target) {
        if (bodyPart == null) {
            return null;
        }
        String b = bodyPart.toUpperCase();
        return switch (b) {
            case "CHEST" -> MuscleGroup.PECTORAUX;
            case "BACK" -> MuscleGroup.DOS;
            case "SHOULDERS" -> MuscleGroup.EPAULES;
            case "BICEPS" -> MuscleGroup.BICEPS;
            case "TRICEPS" -> MuscleGroup.TRICEPS;
            case "WAIST" -> MuscleGroup.ABDOS;
            case "HIPS" -> MuscleGroup.FESSIERS;
            case "CALVES" -> MuscleGroup.MOLLETS;
            case "THIGHS", "QUADRICEPS", "HAMSTRINGS" -> MuscleGroup.JAMBES;
            case "UPPER ARMS", "FOREARMS" ->
                    // Bras : on tranche biceps/triceps selon le muscle cible.
                    (target != null && target.toUpperCase().contains("TRICEPS"))
                            ? MuscleGroup.TRICEPS : MuscleGroup.BICEPS;
            case "FULL BODY", "CARDIO" -> MuscleGroup.CARDIO;
            default -> null; // NECK, FACE, HANDS, FEET... : non mappe
        };
    }

    /** Materiel : projection du premier equipement ExerciseDB sur notre enum. */
    static Equipment toEquipment(List<String> equipments) {
        String eq = first(equipments);
        if (eq == null) {
            return null;
        }
        String e = eq.toUpperCase();
        if (e.contains("BODY WEIGHT") || e.equals("ASSISTED") || e.equals("WEIGHTED")
                || e.equals("SUSPENSION")) return Equipment.POIDS_CORPS;
        if (e.contains("DUMBBELL")) return Equipment.HALTERE;
        if (e.contains("KETTLEBELL")) return Equipment.KETTLEBELL;
        if (e.contains("BARBELL") || e.contains("SMITH MACHINE")
                || e.contains("TRAP BAR")) return Equipment.BARRE;
        if (e.contains("CABLE") || e.contains("ROPE")) return Equipment.POULIE;
        if (e.contains("BAND")) return Equipment.ELASTIQUE;
        if (e.contains("MACHINE") || e.contains("SLED")) return Equipment.MACHINE;
        return null; // MEDICINE BALL, STABILITY BALL, ROLLER, STICK... : non mappe
    }

    private static String first(List<String> list) {
        return (list == null || list.isEmpty()) ? null : list.get(0);
    }
}
