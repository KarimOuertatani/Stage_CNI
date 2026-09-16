package com.fitforge.api.training.importer;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Parametres de l'import ExerciseDB (prefixe {@code fitforge.exercise-import}).
 * Voir application.yaml.
 */
@Component
@ConfigurationProperties(prefix = "fitforge.exercise-import")
@Getter
@Setter
public class ExerciseImportProperties {

    /** Lance l'import au demarrage si vrai (et si le catalogue importe est vide). */
    private boolean enabled = false;

    /** Nombre maximal d'exercices a importer (le plan gratuit plafonne a 200). */
    private int max = 200;
}
