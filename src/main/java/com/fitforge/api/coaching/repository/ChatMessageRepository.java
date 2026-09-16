package com.fitforge.api.coaching.repository;

import com.fitforge.api.coaching.entity.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Acces base pour les messages de chat.
 */
public interface ChatMessageRepository extends JpaRepository<ChatMessage, UUID> {

    /** Historique d'un fil, du plus ancien au plus recent. */
    List<ChatMessage> findByRelationshipIdOrderBySentAtAsc(UUID relationshipId);

    /** Dernier message d'un fil (pour l'apercu dans les listes). */
    ChatMessage findFirstByRelationshipIdOrderBySentAtDesc(UUID relationshipId);

    /** Nombre de messages non lus par l'utilisateur (recus, pas ceux qu'il a envoyes). */
    long countByRelationshipIdAndReadAtIsNullAndSenderIdNot(UUID relationshipId, UUID viewerId);

    /** Marque comme lus tous les messages recus par le lecteur dans ce fil. */
    @Modifying
    @Query("update ChatMessage m set m.readAt = :now " +
            "where m.relationship.id = :relationshipId and m.sender.id <> :readerId and m.readAt is null")
    int markAsRead(@Param("relationshipId") UUID relationshipId,
                   @Param("readerId") UUID readerId,
                   @Param("now") Instant now);
}
