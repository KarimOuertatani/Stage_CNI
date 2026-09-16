package com.fitforge.api.admin.entity;

import com.fitforge.api.common.enums.ProblemCategory;
import com.fitforge.api.common.enums.ProblemStatus;
import com.fitforge.api.common.enums.Role;
import com.fitforge.api.user.entity.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.UUID;

/**
 * Un probleme signale par un adherent ou un coach.
 *
 * <h2>Pourquoi {@code reporterRole} est un instantane et non une lecture</h2>
 * Le role est copie ici au moment du signalement, alors qu'il serait lisible
 * via {@code reporter.getRole()}. C'est deliberé : un adherent peut devenir
 * coach par la suite, et le signalement doit continuer a dire <b>depuis quel
 * espace il a ete envoye</b>. « Le bouton ne marche pas » n'a pas le meme sens
 * selon qu'il vient de l'espace adherent ou de l'espace coach, et c'est souvent
 * la seule indication de l'endroit ou chercher.
 *
 * <h2>Le contexte technique vaut la moitie du diagnostic</h2>
 * {@code platform} et {@code appVersion} sont renseignes par l'application, pas
 * saisis par l'utilisateur. Sans eux, chaque signalement de bug commence par un
 * aller-retour pour demander la version -- aller-retour auquel la plupart des
 * gens ne repondent jamais.
 */
@Entity
@Table(name = "problem_reports")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ProblemReport {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "reporter_id", nullable = false)
    private User reporter;

    /** Role de l'auteur AU MOMENT du signalement (voir l'en-tete de classe). */
    @Enumerated(EnumType.STRING)
    @Column(name = "reporter_role", nullable = false)
    private Role reporterRole;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ProblemCategory category;

    @Column(nullable = false)
    private String subject;

    @Column(nullable = false, length = 4000)
    private String description;

    /**
     * Capture d'ecran facultative, stockee dans le media PUBLIC ({@code /media/}).
     *
     * <p>Contrairement aux justificatifs de coach, il ne s'agit pas d'une piece
     * d'identite : c'est un ecran de l'application que l'utilisateur choisit
     * d'envoyer. Le meme chemin d'upload que les pieces jointes du chat est donc
     * reutilise, plutot que de dupliquer un second mecanisme.
     */
    @Column(name = "attachment_url")
    private String attachmentUrl;

    /** « android 14 », « ios 17 »... renseigne par l'application. */
    private String platform;

    @Column(name = "app_version")
    private String appVersion;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private ProblemStatus status = ProblemStatus.NEW;

    /**
     * Reponse ecrite par l'administrateur, <b>affichee a l'auteur</b> dans
     * l'application. C'est ce qui ferme la boucle : sans elle, le signalement
     * changerait de statut sans que personne ne sache pourquoi.
     */
    @Column(name = "admin_response", length = 2000)
    private String adminResponse;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "handled_by")
    private User handledBy;

    @Column(name = "handled_at")
    private Instant handledAt;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private Instant updatedAt;
}
