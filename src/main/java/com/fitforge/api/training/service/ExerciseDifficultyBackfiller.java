package com.fitforge.api.training.service;

import com.fitforge.api.training.entity.Exercise;
import com.fitforge.api.training.repository.ExerciseRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Renseigne le niveau des exercices qui n'en ont pas encore.
 *
 * <p><b>Pourquoi au demarrage plutot que dans la migration V18 ?</b> Parce que
 * la regle de calcul ({@link ExerciseDifficultyRules}) sert aussi a l'import de
 * nouveaux exercices. La reecrire en {@code CASE} SQL dans la migration
 * reviendrait a maintenir la meme logique a deux endroits, dans deux langages :
 * les deux divergeraient au premier ajustement. Ici, une seule regle, un seul
 * endroit ou se tromper.
 *
 * <p>Le cout est nul en regime normal : une requete {@code count} qui renvoie 0
 * a chaque demarrage suivant. Le traitement ne s'execute donc qu'une fois — a
 * la premiere montee de version, ou apres un import qui aurait laisse des
 * lignes sans niveau.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class ExerciseDifficultyBackfiller implements ApplicationRunner {

    private final ExerciseRepository exerciseRepository;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        List<Exercise> missing = exerciseRepository.findByDifficultyIsNull();
        if (missing.isEmpty()) {
            return;
        }
        for (Exercise exercise : missing) {
            exercise.setDifficulty(ExerciseDifficultyRules.of(exercise));
        }
        exerciseRepository.saveAll(missing);
        log.info("Niveau d'exercice calcule pour {} exercice(s).", missing.size());
    }
}
