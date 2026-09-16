package com.fitforge.api.coaching.ai.entity;

import com.fitforge.api.common.enums.AiCoachRole;
import com.fitforge.api.common.enums.AiCoachTopic;
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
 * Un message du fil avec le <b>coach IA</b>.
 *
 * <p><b>Un seul fil par adherent</b>, et il est prive. Contrairement au chat
 * humain, il n'y a pas de {@code CoachingRelationship} : le coach IA est
 * toujours disponible, sans demande de suivi ni acceptation.
 *
 * <p><b>Pourquoi persister ?</b> Un coach qui oublie tout entre deux ouvertures
 * de l'app n'est pas un coach. L'historique sert deux choses : le reafficher, et
 * surtout le <b>renvoyer au modele</b> comme contexte — c'est ce qui permet
 * « et pour les jambes ? » de vouloir dire quelque chose.
 *
 * <p>Les reponses portent leur {@link #topic} et leur drapeau {@link #refused} :
 * le comportement du coach reste ainsi <b>auditable</b> sans avoir a relire les
 * conversations.
 */
@Entity
@Table(name = "ai_coach_messages", indexes = {
        @Index(name = "idx_ai_coach_user_created", columnList = "user_id, created_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AiCoachMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Proprietaire du fil. Un adherent ne voit jamais que le sien. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private AiCoachRole role;

    /**
     * Texte du message.
     *
     * <p>Borne a 4000 caracteres : la saisie de l'adherent est plafonnee bien
     * plus bas (1000), mais une reponse du modele peut etre longue.
     */
    @Column(nullable = false, length = 4000)
    private String content;

    /**
     * Sujet classe par le modele. Renseigne sur les reponses du coach,
     * {@code null} sur les messages de l'adherent.
     */
    @Enumerated(EnumType.STRING)
    @Column(length = 16)
    private AiCoachTopic topic;

    /**
     * Vrai si la demande a ete <b>declinee</b> pour sortie de perimetre.
     *
     * <p>Le message stocke est alors le refus <i>de l'application</i>, pas
     * celui du modele : le texte est le meme a chaque fois, et il est ecrit par
     * nous ({@code AiCoachService}).
     */
    @Column(nullable = false)
    @Builder.Default
    private boolean refused = false;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
