package com.fitforge.api.user.service;

import com.fitforge.api.common.exception.ResourceNotFoundException;
import com.fitforge.api.user.dto.CreateMeasurementRequest;
import com.fitforge.api.user.dto.MeasurementResponse;
import com.fitforge.api.user.entity.BodyMeasurement;
import com.fitforge.api.user.entity.User;
import com.fitforge.api.user.mapper.MeasurementMapper;
import com.fitforge.api.user.repository.BodyMeasurementRepository;
import com.fitforge.api.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * Logique metier de l'historique des mensurations : ajout, liste, suppression.
 * On n'ecrase jamais une mesure : chaque pesee est une nouvelle ligne.
 */
@Service
@RequiredArgsConstructor
public class MeasurementService {

    private final BodyMeasurementRepository measurementRepo;
    private final UserRepository userRepo;
    private final MeasurementMapper mapper;

    /** Liste des mesures de l'adherent, de la plus recente a la plus ancienne. */
    @Transactional(readOnly = true)
    public List<MeasurementResponse> getMyMeasurements(UUID userId) {
        return measurementRepo.findByUserIdOrderByMeasuredOnDesc(userId).stream()
                .map(mapper::toResponse)
                .toList();
    }

    /** Ajoute une pesee rattachee a l'adherent connecte. */
    @Transactional
    public MeasurementResponse addMeasurement(UUID userId, CreateMeasurementRequest req) {
        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Utilisateur introuvable"));

        BodyMeasurement m = BodyMeasurement.builder()
                .user(user)
                .measuredOn(req.measuredOn())
                .weightKg(req.weightKg())
                .bodyFatPercent(req.bodyFatPercent())
                .waistCm(req.waistCm())
                .chestCm(req.chestCm())
                .armCm(req.armCm())
                .thighCm(req.thighCm())
                .build();

        return mapper.toResponse(measurementRepo.save(m));
    }

    /**
     * Supprime une mesure. Verifie qu'elle appartient bien a l'adherent connecte
     * (on ne supprime jamais la donnee de quelqu'un d'autre).
     */
    @Transactional
    public void deleteMeasurement(UUID userId, UUID measurementId) {
        BodyMeasurement m = measurementRepo.findById(measurementId)
                .orElseThrow(() -> new ResourceNotFoundException("Mesure introuvable"));
        if (!m.getUser().getId().equals(userId)) {
            throw new ResourceNotFoundException("Mesure introuvable");
        }
        measurementRepo.delete(m);
    }
}
