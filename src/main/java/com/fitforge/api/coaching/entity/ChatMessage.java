package com.fitforge.api.coaching.entity;

import com.fitforge.api.common.enums.MediaKind;
import com.fitforge.api.user.entity.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

/**
 * Message de chat echange dans le cadre d'une {@link CoachingRelationship}
 * (le "fil"). Persiste l'historique ; la livraison temps reel se fait en plus
 * via WebSocket/STOMP.
 */
@Entity
@Table(name = "chat_messages", indexes = {
        @Index(name = "idx_chat_relationship", columnList = "relationship_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ChatMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Fil de conversation (la relation de suivi). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "relationship_id", nullable = false)
    private CoachingRelationship relationship;

    /** Auteur du message (coach ou adherent). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sender_id", nullable = false)
    private User sender;

    /**
     * Texte du message. Nullable : un message peut ne contenir qu'une piece
     * jointe (photo, vocal, document) sans texte.
     */
    @Column(length = 2000)
    private String content;

    // ── Piece jointe (optionnelle) ───────────────────────────────

    /** URL publique du fichier joint ({@code /media/<nom>}), ou null. */
    @Column(name = "attachment_url")
    private String attachmentUrl;

    /** Nature de la piece jointe (IMAGE / AUDIO / FILE), ou null. */
    @Enumerated(EnumType.STRING)
    @Column(name = "attachment_kind")
    private MediaKind attachmentKind;

    /** Nom d'origine du fichier (affichage / telechargement). */
    @Column(name = "attachment_name")
    private String attachmentName;

    /** Taille du fichier en octets. */
    @Column(name = "attachment_size")
    private Long attachmentSize;

    /** Duree en secondes pour un vocal/audio (null sinon). */
    @Column(name = "attachment_duration_sec")
    private Integer attachmentDurationSec;

    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private Instant sentAt;

    /** Date de lecture par le destinataire (null = non lu). */
    private Instant readAt;
}
