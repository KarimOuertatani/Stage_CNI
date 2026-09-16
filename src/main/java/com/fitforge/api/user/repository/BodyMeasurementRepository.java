package com.fitforge.api.user.repository;

import com.fitforge.api.user.entity.BodyMeasurement;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

/**
 * Acces base pour l'historique des mensurations.
 */
public interface BodyMeasurementRepository extends JpaRepository<BodyMeasurement, UUID> {

    /** Historique d'un utilisateur, de la mesure la plus recente a la plus ancienne. */
    List<BodyMeasurement> findByUserIdOrderByMeasuredOnDesc(UUID userId);
}
