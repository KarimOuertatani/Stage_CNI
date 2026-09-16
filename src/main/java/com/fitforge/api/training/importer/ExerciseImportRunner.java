package com.fitforge.api.training.importer;

import com.fitforge.api.training.repository.ExerciseRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/**
 * Lance l'import ExerciseDB <b>au demarrage</b> uniquement si demande via la
 * config, et seulement si le catalogue importe est encore vide.
 *
 * <p>Activation ponctuelle sans toucher au code : poser la variable
 * d'environnement {@code IMPORT_EXERCISES=true} (voir application.yaml), lancer
 * le backend une fois pour peupler la base, puis la remettre a false. Evite de
 * consommer le quota RapidAPI a chaque demarrage.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class ExerciseImportRunner implements ApplicationRunner {

    private final ExerciseImportProperties properties;
    private final ExerciseImportService importService;
    private final ExerciseRepository exerciseRepository;

    @Override
    public void run(ApplicationArguments args) {
        if (!properties.isEnabled()) {
            return;
        }
        // Import + enrichissement lances dans un thread separe : ne bloquent pas
        // le demarrage HTTP (l'operation peut durer plusieurs dizaines de secondes).
        Thread worker = new Thread(this::importAndEnrich, "exercisedb-import");
        worker.setDaemon(true);
        worker.start();
        log.info("Import/enrichissement ExerciseDB lance en tache de fond (max={}).",
                properties.getMax());
    }

    private void importAndEnrich() {
        long already = exerciseRepository.countByExternalIdIsNotNull();
        if (already > 0) {
            log.info("Import ExerciseDB ignore : {} exercices deja importes.", already);
        } else {
            importService.importAll(properties.getMax());
        }
        // Toujours tenter d'enrichir les exercices seed sans video (idempotent) :
        // ils alimentent les programmes/modeles, qui gagnent ainsi la video.
        importService.enrichSeedExercises();
    }
}
