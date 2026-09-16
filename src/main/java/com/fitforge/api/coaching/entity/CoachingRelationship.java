package com.fitforge.api.coaching.entity;

import com.fitforge.api.common.enums.CoachingStatus;
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
 * Relation de suivi entre un adherent (member) et un coach.
 * Materialise a la fois la DEMANDE (PENDING) et le SUIVI actif (ACCEPTED).
 * C'est aussi le "fil de conversation" auquel sont rattaches les messages.
 */
@Entity
@Table(name = "coaching_relationships", indexes = {
        @Index(name = "idx_coaching_coach", columnList = "coach_id"),
        @Index(name = "idx_coaching_member", columnList = "member_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CoachingRelationship {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Le coach (User de role COACH). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "coach_id", nullable = false)
    private User coach;

    /** L'adherent qui demande / est suivi. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    private User member;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private CoachingStatus status = CoachingStatus.PENDING;

    /** Message accompagnant la demande de suivi. */
    @Column(length = 1000)
    private String requestMessage;

    @CreationTimestamp
    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    /** Date de reponse du coach (acceptation / refus). */
    private Instant respondedAt;

    /** Date de fin du suivi. */
    private Instant endedAt;
}
