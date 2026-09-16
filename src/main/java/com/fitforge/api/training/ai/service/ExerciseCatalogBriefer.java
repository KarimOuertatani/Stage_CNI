package com.fitforge.api.training.ai.service;

import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.common.enums.MuscleGroup;
import com.fitforge.api.training.entity.Exercise;
import com.fitforge.api.training.repository.ExerciseRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Collection;
import java.util.EnumMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Le catalogue d'exercices, mis a plat pour le modele.
 *
 * <h2>Pourquoi le modele ne nomme pas les exercices lui-meme</h2>
 *
 * <p>C'est la decision qui fait tenir toute la fonctionnalite. Un modele de
 * langage sait parfaitement ecrire « Developpe incline a la barre, 4 x 8 » — et
 * cette phrase n'est <b>rattachable a rien</b>. Notre referentiel a des
 * identifiants, des videos de demonstration, des instructions, un groupe
 * musculaire ; un nom libre n'a rien de tout cela. Il faudrait alors le
 * rapprocher d'un exercice existant apres coup, par comparaison de chaines, et
 * accepter qu'une partie du programme tombe a cote — ou pire, silencieusement
 * sur le mauvais exercice.
 *
 * <p>On inverse donc le sens : le modele ne <b>propose</b> pas des exercices, il
 * <b>choisit</b> dans une liste numerotee qu'on lui fournit. Il ne renvoie que
 * des numeros. Un numero valide designe forcement un exercice reel, avec sa
 * video ; un numero hors bornes est ecarte cote serveur. Il devient impossible
 * de generer un programme contenant un exercice qui n'existe pas.
 *
 * <h2>Ce qui entre dans la liste</h2>
 *
 * <p>Pas tout le catalogue : seulement ce que l'adherent peut <b>reellement
 * faire</b>. Proposer un developpe a la barre a quelqu'un qui s'entraine dans
 * son salon avec deux halteres n'est pas une erreur de forme, c'est un
 * programme inutilisable. Le filtrage par materiel se fait donc <b>avant</b>
 * l'appel, pas apres : ce qui n'est pas realisable n'est jamais propose.
 *
 * <p>La liste est ensuite <b>plafonnee et repartie</b> entre groupes
 * musculaires. Un plafond brut par ordre alphabetique donnerait cent exercices
 * d'abdominaux et aucun de dos ; le tirage tourne donc groupe par groupe.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class ExerciseCatalogBriefer {

    /**
     * Le poids de corps n'est jamais indisponible.
     *
     * <p>Un adherent qui coche « halteres » n'a pas voulu dire qu'il ne peut
     * plus faire de pompes. Cette valeur est donc toujours ajoutee au materiel
     * demande, sans quoi un programme a la maison se retrouverait sans aucun
     * mouvement de base.
     */
    private static final Equipment ALWAYS_AVAILABLE = Equipment.POIDS_CORPS;

    private final ExerciseRepository exerciseRepo;

    /**
     * Taille maximale de la liste soumise au modele.
     *
     * <p>Ce n'est pas qu'une question de cout. Une liste trop longue dilue le
     * choix : le modele picore au lieu de composer. Autour de 150 entrees, il y
     * a de quoi construire n'importe quel decoupage sans noyer la consigne.
     */
    @Value("${gemini.api.program-max-catalog:150}")
    private int maxCatalogSize;

    /**
     * Construit la liste des exercices eligibles.
     *
     * @param equipment materiel demande ; vide = aucun filtre (salle complete)
     * @return le catalogue, dans l'ordre exact ou il sera numerote
     */
    @Transactional(readOnly = true)
    public Catalog build(Collection<Equipment> equipment) {
        List<Exercise> all = exerciseRepo.findAll();

        List<Exercise> eligible = all.stream()
                .filter(e -> e.getName() != null && !e.getName().isBlank())
                .filter(e -> isDoable(e, equipment))
                .toList();

        // Repli : un filtre trop serre (materiel exotique, catalogue partiel)
        // vaut moins qu'un catalogue complet. Mieux vaut un programme a
        // adapter qu'un echec de generation.
        if (eligible.size() < 20) {
            log.debug("Catalogue IA : filtre materiel trop restrictif ({} exercices), "
                    + "repli sur le catalogue complet", eligible.size());
            eligible = all.stream()
                    .filter(e -> e.getName() != null && !e.getName().isBlank())
                    .toList();
        }

        return new Catalog(balance(dedupeByName(eligible)));
    }

    // ── Selection ────────────────────────────────────────────────────

    /**
     * Un exercice est realisable si son materiel fait partie de ce dont
     * l'adherent dispose.
     *
     * <p>Un exercice sans materiel renseigne passe : l'absence d'information
     * n'est pas une contre-indication, et l'ecarter reviendrait a punir les
     * entrees incompletes du catalogue.
     */
    private boolean isDoable(Exercise exercise, Collection<Equipment> available) {
        if (available == null || available.isEmpty()) {
            return true;   // aucune contrainte declaree : tout est permis
        }
        Equipment needed = exercise.getEquipment();
        if (needed == null) {
            return true;
        }
        return needed == ALWAYS_AVAILABLE || available.contains(needed);
    }

    /**
     * Un seul exercice par nom.
     *
     * <p>Le catalogue melange deux origines : 20 exercices seed en francais et
     * ~200 importes d'ExerciseDB en anglais. Les doublons de sens y sont
     * frequents, et proposer deux fois la meme chose au modele revient a lui
     * faire croire qu'il a deux options la ou il n'en a qu'une.
     */
    private List<Exercise> dedupeByName(List<Exercise> exercises) {
        Set<String> seen = new LinkedHashSet<>();
        List<Exercise> unique = new ArrayList<>(exercises.size());
        for (Exercise exercise : exercises) {
            if (seen.add(exercise.getName().trim().toLowerCase(Locale.ROOT))) {
                unique.add(exercise);
            }
        }
        return unique;
    }

    /**
     * Plafonne la liste en tournant groupe musculaire par groupe musculaire.
     *
     * <p>Une simple troncature couperait par ordre de lecture et laisserait des
     * groupes entiers a zero — un programme ne peut pas etre equilibre si la
     * liste ne l'est pas. Le tirage prend donc un exercice de chaque groupe a
     * tour de role jusqu'au plafond.
     */
    private List<Exercise> balance(List<Exercise> exercises) {
        if (exercises.size() <= maxCatalogSize) {
            return exercises;
        }

        Map<MuscleGroup, List<Exercise>> byMuscle = new EnumMap<>(MuscleGroup.class);
        List<Exercise> unclassified = new ArrayList<>();
        for (Exercise exercise : exercises) {
            if (exercise.getPrimaryMuscle() == null) {
                unclassified.add(exercise);
            } else {
                byMuscle.computeIfAbsent(exercise.getPrimaryMuscle(), m -> new ArrayList<>())
                        .add(exercise);
            }
        }

        List<Exercise> picked = new ArrayList<>(maxCatalogSize);
        boolean tookSomething = true;
        for (int round = 0; picked.size() < maxCatalogSize && tookSomething; round++) {
            tookSomething = false;
            for (List<Exercise> group : byMuscle.values()) {
                if (round < group.size() && picked.size() < maxCatalogSize) {
                    picked.add(group.get(round));
                    tookSomething = true;
                }
            }
        }
        // Les exercices sans groupe ne comblent que la place restante : ils sont
        // les moins exploitables pour equilibrer une seance.
        for (Exercise exercise : unclassified) {
            if (picked.size() >= maxCatalogSize) {
                break;
            }
            picked.add(exercise);
        }
        return picked;
    }

    // ── Le catalogue, vu des deux cotes ──────────────────────────────

    /**
     * La liste des exercices eligibles, dans un ordre fige.
     *
     * <p>Cet ordre est le contrat entre les deux cotes de l'appel : le modele
     * lit des numeros ({@link #asPrompt()}), le serveur les retraduit en
     * exercices ({@link #at(int)}). C'est pour cela que le catalogue est un
     * objet et non deux methodes independantes — separer les deux ouvrirait la
     * porte a une numerotation qui glisse d'un cote sans l'autre.
     */
    public static final class Catalog {

        private final List<Exercise> exercises;

        /**
         * Visible dans le paquet pour que les tests puissent construire un
         * catalogue connu — c'est la seule facon d'exercer la retraduction des
         * numeros sans passer par la base.
         */
        Catalog(List<Exercise> exercises) {
            this.exercises = exercises;
        }

        public int size() {
            return exercises.size();
        }

        public boolean isEmpty() {
            return exercises.isEmpty();
        }

        /**
         * L'exercice portant ce numero, ou {@code null} si le numero est hors
         * bornes.
         *
         * <p>Renvoyer {@code null} plutot que lever : un numero invente par le
         * modele est un cas <b>attendu</b>, pas une panne. L'appelant ecarte la
         * ligne et garde le reste du programme.
         */
        public Exercise at(int number) {
            int index = number - 1;   // les numeros commencent a 1, plus lisibles
            return index >= 0 && index < exercises.size() ? exercises.get(index) : null;
        }

        /**
         * Le catalogue tel que le modele le lit.
         *
         * <p>Une ligne par exercice, champs separes par des barres verticales.
         * Pas de JSON : la forme tabulaire coute deux fois moins de jetons et se
         * lit aussi bien. Le groupe musculaire et le materiel sont joints parce
         * que ce sont les deux criteres sur lesquels le modele doit trancher —
         * un nom seul l'obligerait a deviner ce que travaille l'exercice.
         */
        public String asPrompt() {
            StringBuilder sb = new StringBuilder(exercises.size() * 48);
            for (int i = 0; i < exercises.size(); i++) {
                Exercise exercise = exercises.get(i);
                sb.append(i + 1).append(" | ").append(exercise.getName().trim());
                if (exercise.getPrimaryMuscle() != null) {
                    sb.append(" | ").append(exercise.getPrimaryMuscle().name());
                }
                if (exercise.getEquipment() != null) {
                    sb.append(" | ").append(exercise.getEquipment().name());
                }
                sb.append('\n');
            }
            return sb.toString();
        }
    }
}
