package com.fitforge.api.training.repository;

import com.fitforge.api.training.entity.BodyPart;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

/**
 * Acces base pour le referentiel des parties du corps.
 */
public interface BodyPartRepository extends JpaRepository<BodyPart, String> {

    /** Zones ordonnees pour l'affichage. */
    List<BodyPart> findAllByOrderBySortOrderAsc();
}
