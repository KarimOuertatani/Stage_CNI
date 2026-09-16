package com.fitforge.api.training.entity;

import com.fitforge.api.user.entity.User;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Un exercice mis en favori par un adherent.
 *
 * <p>Le catalogue compte plus de 200 exercices ; un pratiquant en utilise une
 * quinzaine. Le favori evite de retraverser « zone du corps -> liste ->
 * recherche » a chaque seance.
 *
 * <p>Cote serveur et non dans le telephone : le favori suit l'adherent d'un
 * appareil a l'autre et survit a une reinstallation. La contrainte d'unicite
 * (user, exercise) rend l'ajout REJOUABLE — un double appui ou un retry reseau
 * ne cree pas deux lignes.
 */
@Entity
@Table(name = "exercise_favorites",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_exercise_favorites",
                columnNames = {"user_id", "exercise_id"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ExerciseFavorite {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "exercise_id", nullable = false)
    private Exercise exercise;

    @CreationTimestamp
    @jakarta.persistence.Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;
}
