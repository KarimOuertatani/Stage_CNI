package com.fitforge.api.training.ai.entity;

import com.fitforge.api.training.entity.WorkoutProgram;
import com.fitforge.api.user.entity.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
 * Une demande de generation de programme, telle qu'elle a ete envoyee au modele.
 *
 * <h2>Pourquoi journaliser ce que l'IA a recu</h2>
 *
 * <p>Trois raisons, par ordre d'importance :
 *
 * <ol>
 *   <li><b>Plafonner.</b> Une generation coute un appel Gemini avec un contexte
 *       lourd (tout le catalogue d'exercices eligibles). Sans compteur, un appui
 *       repete viderait le quota <b>partage</b> avec le coach IA, l'analyse de
 *       photo et l'ajout vocal. C'est cette table qui porte la limite
 *       journaliere.</li>
 *   <li><b>Diagnostiquer.</b> Quand un programme genere est mauvais, la seule
 *       question utile est « sur quelles reponses a-t-il ete construit ? ». Le
 *       brief est donc conserve <b>tel qu'il a ete lu par le modele</b>, en
 *       texte — pas sous forme de champs qu'il faudrait recomposer.</li>
 *   <li><b>Mesurer.</b> Une demande sans {@link #program} est une generation qui
 *       a echoue. Sans cette ligne, les echecs seraient invisibles alors qu'ils
 *       consomment du quota.</li>
 * </ol>
 */
@Entity
@Table(name = "ai_program_requests", indexes = {
        @Index(name = "idx_ai_program_requests_user_created", columnList = "user_id, created_at")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AiProgramRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Adherent qui a demande la generation. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /**
     * Programme produit, ou {@code null} si la generation a echoue.
     *
     * <p>La contrainte est en {@code ON DELETE SET NULL} (voir migration V16) :
     * l'adherent peut supprimer un programme genere sans effacer la trace de la
     * generation, qui est un journal.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "program_id")
    private WorkoutProgram program;

    /** Le brief complet (questionnaire + profil) envoye au modele. */
    @Column(nullable = false, columnDefinition = "text")
    private String brief;

    /** Message d'erreur quand la generation n'a rien produit. */
    @Column(name = "error_message", length = 500)
    private String errorMessage;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
