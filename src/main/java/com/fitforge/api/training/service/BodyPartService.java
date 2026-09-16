package com.fitforge.api.training.service;

import com.fitforge.api.training.dto.BodyPartResponse;
import com.fitforge.api.training.repository.BodyPartRepository;
import com.fitforge.api.training.repository.ExerciseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Navigation « Parcourir par zone » : liste des parties du corps avec, pour
 * chacune, le nombre d'exercices rattaches. Seules les zones ayant au moins un
 * exercice sont renvoyees. Calcul a la volee depuis notre base (aucun appel a
 * l'API externe).
 */
@Service
@RequiredArgsConstructor
public class BodyPartService {

    private final BodyPartRepository bodyPartRepo;
    private final ExerciseRepository exerciseRepo;

    @Transactional(readOnly = true)
    public List<BodyPartResponse> listWithCounts() {
        List<ExerciseRepository.BodyPartCount> rows = exerciseRepo.countByBodyPart();
        Map<String, Long> counts = rows.stream()
                .collect(Collectors.toMap(
                        ExerciseRepository.BodyPartCount::getBodyPart,
                        ExerciseRepository.BodyPartCount::getTotal,
                        (a, b) -> a));
        Map<String, String> photos = rows.stream()
                .filter(r -> r.getSampleImage() != null)
                .collect(Collectors.toMap(
                        ExerciseRepository.BodyPartCount::getBodyPart,
                        ExerciseRepository.BodyPartCount::getSampleImage,
                        (a, b) -> a));

        return bodyPartRepo.findAllByOrderBySortOrderAsc().stream()
                .map(bp -> new BodyPartResponse(
                        bp.getName(),
                        bp.getLabelFr(),
                        bp.getImageUrl(),
                        photos.get(bp.getName()),
                        counts.getOrDefault(bp.getName(), 0L)))
                .filter(bp -> bp.exerciseCount() > 0)
                .toList();
    }
}
