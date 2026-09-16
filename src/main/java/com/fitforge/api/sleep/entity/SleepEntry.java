package com.fitforge.api.sleep.entity;

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
import jakarta.persistence.UniqueConstraint;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

/**
 * Une nuit de sommeil declaree par l'adherent.
 *
 * <h2>Pourquoi la date est celle du reveil</h2>
 *
 * <p>Une nuit est a cheval sur deux jours : il faut choisir lequel la porte.
 * Le coucher ne convient pas — quelqu'un qui se couche a 23 h et quelqu'un qui
 * se couche a 1 h du matin parlent de <b>la meme nuit</b>, mais leur date de
 * coucher differe d'un jour. Le reveil, lui, tombe toujours le meme jour pour
 * les deux. C'est aussi le jour ou l'adherent ouvre l'application pour saisir
 * sa nuit, donc celui qu'il a en tete.
 *
 * <h2>Pourquoi la duree est stockee alors qu'elle se deduit</h2>
 *
 * <p>Elle est lue infiniment plus souvent qu'ecrite : chaque affichage de
 * semaine, chaque moyenne, chaque score. La recalculer a la volee obligerait a
 * reproduire partout la regle du passage de minuit — et c'est exactement le
 * genre de regle qu'on finit par ecrire differemment a deux endroits. Une seule
 * ecriture, un seul endroit ou se tromper ({@link #computeDuration}).
 */
@Entity
@Table(
        name = "sleep_entries",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_sleep_entries_user_date",
                columnNames = {"user_id", "sleep_date"}),
        indexes = @Index(
                name = "idx_sleep_entries_user_date",
                columnList = "user_id, sleep_date"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SleepEntry {

    /** Duree minimale acceptee, en minutes (garde-fou de saisie). */
    public static final int MIN_DURATION_MINUTES = 15;
    /** Duree maximale acceptee, en minutes. */
    public static final int MAX_DURATION_MINUTES = 960;   // 16 h

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Adherent concerne (LAZY). Une nuit n'appartient qu'a lui. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** Jour du <b>reveil</b> — voir la note de classe. */
    @Column(name = "sleep_date", nullable = false)
    private LocalDate sleepDate;

    @Column(name = "bed_time", nullable = false)
    private LocalTime bedTime;

    @Column(name = "wake_time", nullable = false)
    private LocalTime wakeTime;

    /** Duree effective, minuit gere. Toujours coherente avec les deux heures. */
    @Column(name = "duration_minutes", nullable = false)
    private Integer durationMinutes;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /**
     * Duree entre le coucher et le lever, en minutes.
     *
     * <p><b>Le passage de minuit est le cas normal, pas l'exception</b> : se
     * coucher a 23 h et se lever a 7 h donne une heure de lever
     * <i>inferieure</i> a l'heure de coucher. Une soustraction naive renverrait
     * -16 heures. On ajoute donc une journee des que le lever n'est pas
     * strictement posterieur au coucher.
     *
     * <p>Le cas d'egalite (coucher et lever a la meme heure) est traite comme
     * un tour complet de 24 h et sera rejete par les bornes — c'est une saisie
     * erronee, pas une nuit.
     */
    public static int computeDuration(LocalTime bedTime, LocalTime wakeTime) {
        long minutes = Duration.between(bedTime, wakeTime).toMinutes();
        if (minutes <= 0) {
            minutes += Duration.ofDays(1).toMinutes();
        }
        return (int) minutes;
    }

    /** Recalcule et applique la duree depuis les deux heures courantes. */
    public void refreshDuration() {
        this.durationMinutes = computeDuration(bedTime, wakeTime);
    }
}
