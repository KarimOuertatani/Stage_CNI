package com.fitforge.api.training.ai.repository;

import com.fitforge.api.training.ai.entity.AiProgramRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.UUID;

/**
 * Acces base au journal des generations de programme.
 */
public interface AiProgramRequestRepository extends JpaRepository<AiProgramRequest, UUID> {

    /**
     * Nombre de generations demandees par un adherent depuis une date.
     *
     * <p>C'est la requete du plafond journalier. On compte les demandes et
     * <b>non</b> les programmes crees : un echec consomme du quota Gemini
     * exactement comme un succes, il doit donc compter pareil.
     */
    @Query("""
            SELECT COUNT(r) FROM AiProgramRequest r
            WHERE r.user.id = :userId AND r.createdAt >= :since
            """)
    long countSince(@Param("userId") UUID userId, @Param("since") Instant since);
}
