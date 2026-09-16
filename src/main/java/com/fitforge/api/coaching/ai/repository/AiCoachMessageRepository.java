package com.fitforge.api.coaching.ai.repository;

import com.fitforge.api.coaching.ai.entity.AiCoachMessage;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Acces au fil du coach IA. Toutes les methodes sont <b>portees par
 * l'adherent</b> : il n'existe aucun moyen de lire le fil de quelqu'un d'autre.
 */
public interface AiCoachMessageRepository extends JpaRepository<AiCoachMessage, UUID> {

    /** Le fil complet, du plus ancien au plus recent (ordre d'affichage). */
    List<AiCoachMessage> findByUserIdOrderByCreatedAtAsc(UUID userId);

    /**
     * Les {@code n} derniers messages, du plus <b>recent</b> au plus ancien.
     *
     * <p>Sert a constituer le contexte envoye au modele. L'ordre descendant est
     * volontaire : c'est la <i>fin</i> de la conversation qui compte, et c'est
     * elle qu'on veut garder quand on tronque. L'appelant reinverse la liste.
     */
    @Query("""
            select m from AiCoachMessage m
            where m.user.id = :userId
            order by m.createdAt desc
            """)
    List<AiCoachMessage> findRecent(@Param("userId") UUID userId, Pageable pageable);

    /**
     * Nombre de messages envoyes par l'adherent depuis un instant donne.
     *
     * <p>Garde-fou de quota : chaque message coute un appel Gemini. On ne
     * compte que les messages {@code USER}, les reponses n'etant pas a la main
     * de l'adherent.
     */
    @Query("""
            select count(m) from AiCoachMessage m
            where m.user.id = :userId
              and m.role = com.fitforge.api.common.enums.AiCoachRole.USER
              and m.createdAt >= :since
            """)
    long countUserMessagesSince(@Param("userId") UUID userId, @Param("since") Instant since);

    /** Efface le fil d'un adherent (« nouvelle conversation »). */
    @Modifying
    @Query("delete from AiCoachMessage m where m.user.id = :userId")
    void deleteByUserId(@Param("userId") UUID userId);
}
