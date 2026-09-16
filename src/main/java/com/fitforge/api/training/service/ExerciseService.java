package com.fitforge.api.training.service;

import com.fitforge.api.common.enums.Equipment;
import com.fitforge.api.common.enums.ExperienceLevel;
import com.fitforge.api.common.enums.MuscleGroup;
import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.training.dto.ExerciseResponse;
import com.fitforge.api.training.entity.Exercise;
import com.fitforge.api.training.entity.ExerciseFavorite;
import com.fitforge.api.training.mapper.ExerciseMapper;
import com.fitforge.api.training.repository.ExerciseFavoriteRepository;
import com.fitforge.api.training.repository.ExerciseRepository;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Locale;
import java.util.UUID;

/**
 * Logique metier du referentiel d'exercices (lecture seule cote adherent),
 * plus la gestion des favoris.
 */
@Service
@RequiredArgsConstructor
public class ExerciseService {

    private final ExerciseRepository exerciseRepo;
    private final ExerciseFavoriteRepository favoriteRepo;
    private final UserRepository userRepo;
    private final ExerciseMapper mapper;

    /**
     * Liste filtree : tous les criteres sont optionnels et se combinent.
     *
     * @param q texte libre — cherche dans le nom, les mots-cles et les muscles.
     *          Normalise ici (minuscules + jokers) plutot que dans la requete :
     *          la requete reste alors constante, donc reutilisable telle quelle.
     */
    @Transactional(readOnly = true)
    public List<ExerciseResponse> search(MuscleGroup muscle,
                                         Equipment equipment,
                                         String bodyPart,
                                         ExperienceLevel level,
                                         String q) {
        String pattern = (q == null || q.isBlank())
                ? null
                : "%" + q.trim().toLowerCase(Locale.ROOT) + "%";
        return exerciseRepo.search(muscle, equipment, bodyPart, level, pattern).stream()
                .map(mapper::toResponse)
                .toList();
    }

    /** Detail d'un exercice. */
    @Transactional(readOnly = true)
    public ExerciseResponse getById(UUID id) {
        return exerciseRepo.findById(id)
                .map(mapper::toResponse)
                .orElseThrow(() -> new ResourceNotFoundException("Exercice introuvable"));
    }

    // ─────────────────────────────────────────────────────────────────────
    //  Favoris
    // ─────────────────────────────────────────────────────────────────────

    /** Mes exercices favoris, le dernier ajoute en tete. */
    @Transactional(readOnly = true)
    public List<ExerciseResponse> getFavorites(UUID userId) {
        return favoriteRepo.findFavoriteExercises(userId).stream()
                .map(mapper::toResponse)
                .toList();
    }

    /**
     * Ajoute un exercice aux favoris. IDEMPOTENT : rappeler l'operation sur un
     * exercice deja favori ne change rien et ne leve pas d'erreur — c'est ce qui
     * permet au telephone de rejouer l'appel apres une coupure reseau sans avoir
     * a distinguer « deja fait » de « a faire ».
     */
    @Transactional
    public void addFavorite(UUID userId, UUID exerciseId) {
        if (favoriteRepo.existsByUserIdAndExerciseId(userId, exerciseId)) {
            return;
        }
        Exercise exercise = exerciseRepo.findById(exerciseId)
                .orElseThrow(() -> new ResourceNotFoundException("Exercice introuvable"));
        favoriteRepo.save(ExerciseFavorite.builder()
                .user(userRepo.getReferenceById(userId))
                .exercise(exercise)
                .build());
    }

    /** Retire un exercice des favoris. Idempotent lui aussi. */
    @Transactional
    public void removeFavorite(UUID userId, UUID exerciseId) {
        favoriteRepo.deleteByUserIdAndExerciseId(userId, exerciseId);
    }
}
