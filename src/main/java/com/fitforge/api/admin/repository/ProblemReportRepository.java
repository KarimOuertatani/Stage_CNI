package com.fitforge.api.admin.repository;

import com.fitforge.api.admin.entity.ProblemReport;
import com.fitforge.api.common.enums.ProblemStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

/** Acces base pour les signalements. */
public interface ProblemReportRepository extends JpaRepository<ProblemReport, UUID> {

    /** « Mes signalements », cote utilisateur : les plus recents d'abord. */
    List<ProblemReport> findByReporterIdOrderByCreatedAtDesc(UUID reporterId);

    /**
     * File de traitement, du plus ancien au plus recent -- meme raisonnement que
     * pour les candidatures coach : une file triee a l'envers laisse les vieux
     * signalements sombrer sans jamais etre traites.
     */
    Page<ProblemReport> findByStatusOrderByCreatedAtAsc(ProblemStatus status, Pageable pageable);

    Page<ProblemReport> findAllByOrderByCreatedAtDesc(Pageable pageable);

    long countByStatus(ProblemStatus status);
}
