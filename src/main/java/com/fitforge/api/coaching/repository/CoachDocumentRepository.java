package com.fitforge.api.coaching.repository;

import com.fitforge.api.coaching.entity.CoachDocument;
import com.fitforge.api.common.enums.CoachDocumentType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

/** Acces base pour les justificatifs de candidature des coachs. */
public interface CoachDocumentRepository extends JpaRepository<CoachDocument, UUID> {

    List<CoachDocument> findByCoachProfileIdOrderByUploadedAtAsc(UUID coachProfileId);

    /** Sert au controle de completude avant soumission (piece d'identite presente ?). */
    boolean existsByCoachProfileIdAndType(UUID coachProfileId, CoachDocumentType type);

    long countByCoachProfileId(UUID coachProfileId);
}
